{-# LANGUAGE DeriveGeneric #-}


module OSL.Types.Sigma11
  ( Name (Name)
  , Term (..)
  , Formula (..)
  ) where


import Data.List.NonEmpty (NonEmpty)
import Data.Generics.Labels ()
import GHC.Generics (Generic)

import OSL.Types.Arity (Arity)
import OSL.Types.DeBruijnIndex (DeBruijnIndex)


data Name = Name { arity :: Arity, deBruijnIndex :: DeBruijnIndex }
  deriving (Eq, Ord, Generic)


data Term =
    Var Name
  | App Name (NonEmpty Term)
  | Add Term Term
  | Mul Term Term
  | IndLess Term Term
  | Const Integer


data Formula =
    Equals Term Term
  | Not Formula
  | And Formula Formula
  | Or Formula Formula
  | Implies Formula Formula
  | ForAll Term Formula
  | ExistsFO Term Formula -- first order existential
  | ExistsSO Term (NonEmpty Term) Formula -- second order existential
