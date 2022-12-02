{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Halo2.Types.LogicConstraint
  ( AtomicLogicConstraint (Equals, LessThan, EqualsMax),
    LogicConstraint (Atom, Not, And, Or, Iff, Top, Bottom),
    atomicConstraintArgs,
  )
where

import Halo2.Prelude
import Halo2.Types.Polynomial (Polynomial)

data AtomicLogicConstraint
  = Equals Polynomial Polynomial
  | LessThan Polynomial Polynomial
  | EqualsMax Polynomial Polynomial Polynomial
  deriving (Eq, Ord)

instance Show AtomicLogicConstraint where
  show (Equals x y) =
    "(" <> show x <> " = " <> show y <> ")"
  show (LessThan x y) =
    "(" <> show x <> " < " <> show y <> ")"
  show (EqualsMax x y z) =
    "(max(" <> show x <> ", " <> show y <> ") = " <> show z <> ")"

atomicConstraintArgs :: AtomicLogicConstraint -> [Polynomial]
atomicConstraintArgs =
  \case
    Equals a b -> [a, b]
    LessThan a b -> [a, b]
    EqualsMax a b c -> [a, b, c]

data LogicConstraint
  = Atom AtomicLogicConstraint
  | Not LogicConstraint
  | And LogicConstraint LogicConstraint
  | Or LogicConstraint LogicConstraint
  | Iff LogicConstraint LogicConstraint
  | Top
  | Bottom

instance Show LogicConstraint where
  show (Atom x) = show x
  show (Not p) = "!" <> show p
  show (And p q) =
    "(" <> show p <> " & " <> show q <> ")"
  show (Or p q) =
    "(" <> show p <> " | " <> show q <> ")"
  show (Iff p q) =
    "(" <> show p <> " <-> " <> show q <> ")"
  show Top = "⊤"
  show Bottom = "⊥"
