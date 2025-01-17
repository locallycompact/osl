{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StandaloneKindSignatures #-}
{-# LANGUAGE ViewPatterns #-}

module Stark.Types.Scalar
  ( Scalar,
    order,
    epsilon,
    fromWord64,
    toWord64,
    inverseScalar,
    generator,
    primitiveBigPowerOfTwoRoot,
    primitiveNthRoot,
    sample,
    scalarToRational,
    scalarToInt,
    scalarToInteger,
    integerToScalar,
    zero,
    one,
    minusOne,
    two,
    half,
    normalize,
  )
where

import qualified Algebra.Additive as Group
import qualified Algebra.Ring as Ring
import Basement.Types.Word128 (Word128 (Word128))
import Cast
  ( integerToWord64,
    word64ToInteger,
    word64ToRatio,
    word8ToInteger,
  )
import Control.Monad (guard)
import Data.Bits (shiftR, toIntegralSized, (.&.))
import qualified Data.ByteString as BS
import Data.Kind (Type)
import Data.Maybe (fromMaybe)
import Data.Ratio (denominator, numerator)
import Data.Text (pack)
import Data.Word (Word64)
import Die (die)
import GHC.Generics (Generic)

-- |
--  Finite field of order (2^64 - 2^32) + 1, or equivalently, 2^64 - 0xFFFFFFFF.
--  The idea of this representation is taken from these sources:
--  - Plonky2: https://github.com/mir-protocol/plonky2/blob/e127d5a4b11a9d5074b25d1d2dd2b765f404fbe3/field/src/goldilocks_field.rs
--  - Some blog post: https://www.craig-wood.com/nick/armprime/math/
--  The notable thing about this representation is that _all_ 'Word64's are a valid 'Scalar',
--  but they don't always mean the same thing.
--  Up until (not including) 2^64 - 0xFFFFFFFF, 'Word64' and 'Scalar' have the same meaning.
--  Howevere, in the case of 'Scalar', from 2^64 - 0xFFFFFFFF and upto (not including) 2^64, it wraps around.
--  This means that we have e.g. 2 0s in 'Scalar'. One at 0, and one at 2^64 - 0xFFFFFFFF.
--  Thus, when we need the _canonical_ representation, we need to _reduce_ it, which essentially
--  means: if less than the order, keep as is, otherwise, add 0xFFFFFFFF.
--  We have some other nice properties as noted in the blog post, and similar tricks
--  can be used for the various arithmetic operators.
type Scalar :: Type
newtype Scalar = Scalar {unScalar :: Word64}
  deriving stock (Generic)
  deriving newtype (Show)

instance Group.C Scalar where
  zero = zero
  (+) = addScalar
  negate = negateScalar

instance Ring.C Scalar where
  one = one
  (*) = mulScalar

epsilon :: Word64
epsilon = 0xFFFFFFFF

order :: Word64
order = 0xFFFFFFFF00000001

fromWord64 :: Word64 -> Maybe Scalar
fromWord64 x | x < order = Just $ Scalar x
fromWord64 _ = Nothing

toWord64 :: Scalar -> Word64
toWord64 (Scalar x) =
  if x < order
    then x
    else x + epsilon

up :: Word64 -> Word128
up = Word128 0

-- would be great if we could check for overflow easily
addScalar :: Scalar -> Scalar -> Scalar
addScalar (toWord64 -> x) (toWord64 -> y) =
  let r = x + y
   in Scalar $
        if r < x || r < y
          then -- if we've underflowed, we've skipped `epsilon` amount, so we must add it back
            r + epsilon
          else r

negateScalar :: Scalar -> Scalar
negateScalar (Scalar x) = Scalar $ order - x -- very simple

-- FIXME: Why is this algorithm correct? Give an informal proof.
mulScalar :: Scalar -> Scalar -> Scalar
mulScalar (Scalar x) (Scalar y) =
  case up x * up y of
    Word128 hi lo ->
      let hihi = shiftR hi 32
          hilo = hi .&. epsilon
          Word128 borrow t0 = up lo - up hihi
          t1 = if borrow > 0 then t0 - epsilon else t0
       in Scalar t1 + Scalar (hilo * epsilon)

inverseScalar :: Scalar -> Maybe Scalar
inverseScalar (Scalar 0) = Nothing
inverseScalar (Scalar ((+ epsilon) -> 0)) = Nothing
inverseScalar x = Just $ x ^ (order - 2)

generator :: Scalar
generator = Scalar 7

primitiveBigPowerOfTwoRoot :: Scalar
primitiveBigPowerOfTwoRoot = case primitiveNthRoot (2 ^ (32 :: Integer)) of
  Just x -> x
  Nothing -> die "impossible"

normalize :: Scalar -> Scalar
normalize = Scalar . toWord64

primitiveNthRoot :: Word64 -> Maybe Scalar
primitiveNthRoot n = do
  guard (n <= initOrder)
  guard (n .&. (n - 1) == 0)
  pure . normalize $ f initRoot initOrder
  where
    initRoot = generator ^ (4294967295 :: Int)

    initOrder :: Word64
    initOrder = 2 ^ (32 :: Integer)

    f :: Num p => p -> Word64 -> p
    f root order' =
      if order' /= n
        then f (root * root) (order' `quot` 2)
        else root

instance Bounded Scalar where
  minBound = Scalar 0
  maxBound = Scalar (order - 1)

instance Num Scalar where
  fromInteger n =
    case fromWord64 . fromInteger $
      n `mod` word64ToInteger order of
      Just n' -> n'
      Nothing -> die (pack (show n) <> " is not less than " <> pack (show order))
  (+) = addScalar
  (*) = mulScalar
  negate = negateScalar
  abs = die "abs Scalar unimplemented"
  signum = die "signum Scalar unimplemented"

instance Fractional Scalar where
  recip x = case inverseScalar x of
    Just y -> y
    Nothing -> die "0 has no reciprocal"
  fromRational x =
    (if x < 0 then negate else id) $
      fromInteger (numerator (abs x))
        / fromInteger (denominator (abs x))

instance Eq Scalar where
  x == y = toWord64 (normalize x) == toWord64 (normalize y)

instance Ord Scalar where
  compare x y = compare (toWord64 (normalize x)) (toWord64 (normalize y))

instance Real Scalar where
  toRational = toRational . toWord64

sample :: BS.ByteString -> Scalar
sample = fromInteger . sampleInteger

sampleInteger :: BS.ByteString -> Integer
sampleInteger = BS.foldl (\x b -> x + word8ToInteger b) 0

scalarToInteger :: Scalar -> Integer
scalarToInteger = word64ToInteger . unScalar

scalarToRational :: Scalar -> Rational
scalarToRational = word64ToRatio . unScalar

integerToScalar :: Integer -> Maybe Scalar
integerToScalar n =
  if n >= 0
    then fromWord64 =<< integerToWord64 n
    else negateScalar <$> integerToScalar (negate n)

scalarToInt :: Scalar -> Int
scalarToInt = fromMaybe (die "scalarToInt partiality") . toIntegralSized . toWord64

zero, one, minusOne, two, half :: Scalar
zero = fromMaybe (die "zero: partiality") (fromWord64 0)
one = fromMaybe (die "zero: partiality") (fromWord64 1)
minusOne = negateScalar one
two = fromMaybe (die "zero: partiality") (fromWord64 2)
half = fromMaybe (die "half: partiality") (inverseScalar two)
