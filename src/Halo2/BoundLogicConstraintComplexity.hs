{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedLabels #-}
{-# LANGUAGE OverloadedLists #-}


module Halo2.BoundLogicConstraintComplexity
  ( ComplexityBound (ComplexityBound)
  , boundLogicConstraintComplexity
  ) where


import Control.Lens ((^.))
import Control.Monad.Trans.State (State, execState, get, put)
import qualified Data.Map as Map
import GHC.Generics (Generic)
import Halo2.Polynomial (var', constant)
import Halo2.Types.ColumnIndex (ColumnIndex)
import Halo2.Types.ColumnType (ColumnType (Advice))
import Halo2.Types.ColumnTypes (ColumnTypes (ColumnTypes))
import Halo2.Types.LogicConstraint (LogicConstraint (Atom, And, Not, Or, Iff, Top, Bottom), AtomicLogicConstraint (Equals))
import Halo2.Types.LogicConstraints (LogicConstraints (LogicConstraints))
import Halo2.Types.Circuit (LogicCircuit, Circuit (Circuit))


newtype ComplexityBound = ComplexityBound { unComplexityBound :: Int }
  deriving (Eq, Ord, Num, Generic)


data S = S ColumnTypes LogicConstraints
  deriving Generic


boundLogicConstraintComplexity
  :: ComplexityBound
  -> LogicCircuit
  -> LogicCircuit
boundLogicConstraintComplexity bound x =
  let S colTypes gateConstraints = execState
        (mapM_ (go bound) (x ^. #gateConstraints . #constraints))
        (S (x ^. #columnTypes) (LogicConstraints mempty (x ^. #gateConstraints . #bounds)))
  in Circuit
     colTypes
     (x ^. #equalityConstrainableColumns)
     gateConstraints
     (x ^. #lookupArguments)
     (x ^. #rowCount)
     (x ^. #equalityConstraints)
     (x ^. #fixedValues)


go :: ComplexityBound -> LogicConstraint -> State S ()
go n p = addConstraint =<< go' n p


go' :: ComplexityBound -> LogicConstraint -> State S LogicConstraint
go' 0 (Atom p) = pure (Atom p)
go' 0 p = do
  i <- addCol
  addConstraint (Atom (var' i `Equals` constant 1) `Iff` p)
  pure (Atom (var' i `Equals` constant 1))
go' n r =
  case r of
    Atom p -> pure (Atom p)
    Not p -> Not <$> go' n p
    And p q -> And <$> go' (n-1) p <*> go' (n-1) q
    Or p q -> Or <$> go' (n-1) p <*> go' (n-1) q
    Iff p q -> Iff <$> go' (n-1) p <*> go' (n-1) q
    Top -> pure Top
    Bottom -> pure Bottom


addConstraint :: LogicConstraint -> State S ()
addConstraint p = do
  S colTypes constraints <- get
  put (S colTypes (constraints <> LogicConstraints [p] mempty))


addCol :: State S ColumnIndex
addCol = do
  -- TODO: add a range check for the new column
  S colTypes constraints <- get
  let i = maybe 0 ((1+) . fst) (Map.lookupMax (colTypes ^. #getColumnTypes))
  put (S (colTypes <> ColumnTypes (Map.singleton i Advice)) constraints)
  pure i
