{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedLabels #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Halo2.LogicToArithmetic
  ( eval,
    translateLogicGate,
    byteDecompositionGate,
    getLayout,
    getSignRangeCheck,
    getByteRangeAndTruthTableChecks,
    logicToArithmeticCircuit,
  )
where

import Cast (intToInteger)
import Control.Monad (forM, replicateM)
import Control.Monad.State (State, evalState, get, put)
import Crypto.Number.Basic (numBits)
import Data.List (foldl')
import qualified Data.Map as Map
import qualified Data.Set as Set
import Halo2.ByteDecomposition (countBytes)
import qualified Halo2.Coefficient as C
import qualified Halo2.FiniteField as F
import qualified Halo2.Polynomial as P
import Halo2.Prelude
import Halo2.TruthTable (getByteRangeColumn, getZeroIndicatorColumn)
import Halo2.Types.BitsPerByte (BitsPerByte (..))
import Halo2.Types.Circuit (ArithmeticCircuit, Circuit (..), LogicCircuit)
import Halo2.Types.ColumnIndex (ColumnIndex (..))
import Halo2.Types.ColumnType (ColumnType (Fixed))
import Halo2.Types.ColumnTypes (ColumnTypes (..))
import Halo2.Types.FiniteField (FiniteField (..))
import Halo2.Types.FixedBound (FixedBound (..))
import Halo2.Types.FixedValues (FixedValues (..))
import Halo2.Types.InputExpression (InputExpression (..))
import Halo2.Types.LogicConstraint (AtomicLogicConstraint (..), LogicConstraint (..), atomicConstraintArgs)
import Halo2.Types.LogicToArithmeticColumnLayout (AtomAdvice (..), ByteColumnIndex (..), ByteRangeColumnIndex (..), LogicToArithmeticColumnLayout (..), SignColumnIndex (..), TruthTableColumnIndices (..), TruthValueColumnIndex (..), ZeroIndicatorColumnIndex (..))
import Halo2.Types.LookupArgument (LookupArgument (..))
import Halo2.Types.LookupArguments (LookupArguments (..))
import Halo2.Types.LookupTableColumn (LookupTableColumn (..))
import Halo2.Types.Polynomial (Polynomial (..))
import Halo2.Types.PolynomialConstraints (PolynomialConstraints (..))
import Halo2.Types.PolynomialDegreeBound (PolynomialDegreeBound (..))
import Halo2.Types.PolynomialVariable (PolynomialVariable (..))
import Halo2.Types.RowCount (RowCount)

translateLogicGate ::
  FiniteField ->
  LogicToArithmeticColumnLayout ->
  LogicConstraint ->
  Maybe Polynomial
translateLogicGate f layout p =
  P.minus f <$> eval f layout p <*> pure P.one

byteDecompositionGate ::
  FiniteField ->
  LogicToArithmeticColumnLayout ->
  AtomicLogicConstraint ->
  Maybe Polynomial
byteDecompositionGate f layout c =
  let (a, b) = atomicConstraintArgs c
   in do
        advice <- Map.lookup c (layout ^. #atomAdvice)
        pure $
          P.minus
            f
            (P.minus f a b)
            ( P.times
                f
                ( P.var
                    ( PolynomialVariable
                        (advice ^. #sign . #unSignColumnIndex)
                        0
                    )
                )
                ( P.sum
                    f
                    [ P.times f (P.constant (2 ^ j)) d
                      | (j, d) :: (Integer, Polynomial) <-
                          zip
                            [0 ..]
                            ( reverse
                                ( P.var
                                    . flip PolynomialVariable 0
                                    . unByteColumnIndex
                                    <$> (advice ^. #bytes)
                                )
                            )
                    ]
                )
            )

eval ::
  FiniteField ->
  LogicToArithmeticColumnLayout ->
  LogicConstraint ->
  Maybe Polynomial
eval f layout =
  \case
    Atom (Equals p q) -> do
      advice <- Map.lookup (Equals p q) (layout ^. #atomAdvice)
      pure $ P.times f (signPoly f advice) (eqMono advice)
    Atom (LessThan p q) -> do
      advice <- Map.lookup (LessThan p q) (layout ^. #atomAdvice)
      pure $
        P.times
          f
          (signPoly f advice)
          (some f (unTruthValueColumnIndex <$> advice ^. #truthValue))
    Not p -> P.minus f P.one <$> rec p
    And p q -> P.times f <$> rec p <*> rec q
    Or p q ->
      let a = rec p
          b = rec q
       in P.plus f <$> a <*> (P.minus f <$> b <*> (P.times f <$> a <*> b))
  where
    rec = eval f layout

signPoly :: FiniteField -> AtomAdvice -> Polynomial
signPoly f advice =
  P.times
    f
    (P.constant (F.half f))
    ( P.plus
        f
        (P.constant F.one)
        ( P.var
            ( PolynomialVariable
                (advice ^. #sign . #unSignColumnIndex)
                0
            )
        )
    )

eqMono :: AtomAdvice -> Polynomial
eqMono advice =
  P.multilinearMonomial C.one $
    flip PolynomialVariable 0 . unTruthValueColumnIndex
      <$> advice ^. #truthValue

some :: FiniteField -> [ColumnIndex] -> Polynomial
some _ [] = P.zero
some f (x : xs) =
  let a = P.var (PolynomialVariable x 0)
      b = some f xs
   in P.plus f a (P.minus f b (P.times f a b))

getLayout ::
  BitsPerByte ->
  FiniteField ->
  LogicCircuit ->
  LogicToArithmeticColumnLayout
getLayout bits f lc =
  let i0 =
        ColumnIndex . length $
          lc ^. #columnTypes . #getColumnTypes
   in evalState (getLayoutM bits f lc) i0

getLayoutM ::
  BitsPerByte ->
  FiniteField ->
  LogicCircuit ->
  State ColumnIndex LogicToArithmeticColumnLayout
getLayoutM bits f lc = do
  tabi0 <- ByteRangeColumnIndex <$> nextColIndex
  tabi1 <- ZeroIndicatorColumnIndex <$> nextColIndex
  atomAdvices <- fmap Map.fromList
    . forM (Set.toList (getAtomicConstraints lc))
    $ \ac ->
      (ac,) <$> getAtomAdviceM bits f
  let colTypes =
        lc ^. #columnTypes
          <> ColumnTypes [Fixed, Fixed]
      lcCols =
        Set.fromList . fmap ColumnIndex $
          [ 0
            .. length (lc ^. #columnTypes . #getColumnTypes)
              - 1
          ]
  pure $
    LogicToArithmeticColumnLayout
      colTypes
      lcCols
      atomAdvices
      (TruthTableColumnIndices tabi0 tabi1)

getAtomAdviceM ::
  BitsPerByte ->
  FiniteField ->
  State ColumnIndex AtomAdvice
getAtomAdviceM bits (FiniteField fieldSize) = do
  AtomAdvice
    <$> (SignColumnIndex <$> nextColIndex)
    <*> replicateM n (ByteColumnIndex <$> nextColIndex)
    <*> replicateM n (TruthValueColumnIndex <$> nextColIndex)
  where
    n = countBytes bits (FixedBound fieldSize)

getAtomicConstraints :: LogicCircuit -> Set AtomicLogicConstraint
getAtomicConstraints lc =
  Set.unions $
    getAtomicSubformulas
      <$> lc ^. #gateConstraints . #constraints

getAtomicSubformulas :: LogicConstraint -> Set AtomicLogicConstraint
getAtomicSubformulas =
  \case
    Atom a -> Set.singleton a
    Not p -> rec p
    And p q -> rec p <> rec q
    Or p q -> rec p <> rec q
  where
    rec = getAtomicSubformulas

getSignRangeCheck ::
  FiniteField ->
  LogicToArithmeticColumnLayout ->
  AtomicLogicConstraint ->
  Maybe LookupArgument
getSignRangeCheck f layout c = do
  advice <- Map.lookup c (layout ^. #atomAdvice)
  pure . LookupArgument $
    [ ( InputExpression (signPoly f advice),
        LookupTableColumn $
          layout
            ^. #truthTable
              . #zeroIndicatorColumnIndex
              . #unZeroIndicatorColumnIndex
      )
    ]

getByteRangeAndTruthTableChecks ::
  LogicToArithmeticColumnLayout ->
  AtomicLogicConstraint ->
  Maybe LookupArgument
getByteRangeAndTruthTableChecks layout c = do
  advice <- Map.lookup c (layout ^. #atomAdvice)
  let b0 =
        layout
          ^. #truthTable
            . #zeroIndicatorColumnIndex
            . #unZeroIndicatorColumnIndex
      b1 =
        layout
          ^. #truthTable
            . #byteRangeColumnIndex
            . #unByteRangeColumnIndex
  pure . LookupArgument $ do
    (byteCol, truthValCol) <-
      zip
        (advice ^. #bytes)
        (advice ^. #truthValue)
    let delta = P.var (PolynomialVariable (truthValCol ^. #unTruthValueColumnIndex) 0)
        beta = P.var (PolynomialVariable (byteCol ^. #unByteColumnIndex) 0)
    [ (InputExpression delta, LookupTableColumn b0),
      (InputExpression beta, LookupTableColumn b1)
      ]

nextColIndex :: State ColumnIndex ColumnIndex
nextColIndex = do
  i <- get
  put (i + 1)
  pure i

getPolyDegreeBound :: Polynomial -> PolynomialDegreeBound
getPolyDegreeBound p =
  PolynomialDegreeBound $
    2 ^ numBits (intToInteger (P.degree p))

logicToArithmeticCircuit ::
  BitsPerByte ->
  FiniteField ->
  RowCount ->
  LogicCircuit ->
  Maybe ArithmeticCircuit
logicToArithmeticCircuit bits f rows lc = do
  let layout = getLayout bits f lc
      atoms = Set.toList (getAtomicConstraints lc)
  translatedGates <-
    forM (lc ^. #gateConstraints . #constraints) $
      translateLogicGate f layout
  decompositionGates <-
    forM atoms $ byteDecompositionGate f layout
  let polyGates = translatedGates <> decompositionGates
      degreeBound =
        foldl'
          max
          0
          (getPolyDegreeBound <$> polyGates)
  signChecks <-
    forM atoms $ getSignRangeCheck f layout
  rangeAndTruthChecks <-
    forM atoms $ getByteRangeAndTruthTableChecks layout
  pure $
    Circuit
      f
      (layout ^. #columnTypes)
      (lc ^. #equalityConstrainableColumns)
      (PolynomialConstraints polyGates degreeBound)
      ( (lc ^. #lookupArguments)
          <> LookupArguments signChecks
          <> LookupArguments rangeAndTruthChecks
      )
      rows
      (lc ^. #equalityConstraints)
      ( (lc ^. #fixedValues)
          <> FixedValues
            ( Map.singleton
                ( layout
                    ^. #truthTable
                      . #byteRangeColumnIndex
                      . #unByteRangeColumnIndex
                )
                (getByteRangeColumn bits rows)
            )
          <> FixedValues
            ( Map.singleton
                ( layout
                    ^. #truthTable
                      . #zeroIndicatorColumnIndex
                      . #unZeroIndicatorColumnIndex
                )
                (getZeroIndicatorColumn rows)
            )
      )