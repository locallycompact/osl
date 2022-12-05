{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module Trace.Types
  ( InputColumnIndex (InputColumnIndex),
    OutputColumnIndex (OutputColumnIndex),
    StepType (StepType),
    StepTypeId (StepTypeId),
    SubexpressionId (SubexpressionId),
    InputSubexpressionId (InputSubexpressionId),
    OutputSubexpressionId (OutputSubexpressionId),
    SubexpressionLink (SubexpressionLink),
    ResultExpressionId (ResultExpressionId),
    StepTypeColumnIndex (StepTypeColumnIndex),
    StepIndicatorColumnIndex (StepIndicatorColumnIndex),
    CaseNumberColumnIndex (CaseNumberColumnIndex),
    NumberOfCases (NumberOfCases),
    TraceType (TraceType),
  )
where

import Halo2.Prelude
import Halo2.Types.ColumnIndex (ColumnIndex)
import Halo2.Types.ColumnTypes (ColumnTypes)
import Halo2.Types.EqualityConstrainableColumns (EqualityConstrainableColumns)
import Halo2.Types.EqualityConstraints (EqualityConstraints)
import Halo2.Types.FixedValues (FixedValues)
import Halo2.Types.LookupArguments (LookupArguments)
import Halo2.Types.Polynomial (Polynomial)
import Halo2.Types.PolynomialConstraints (PolynomialConstraints)
import Halo2.Types.RowCount (RowCount)
import Stark.Types.Scalar (Scalar)

newtype InputColumnIndex = InputColumnIndex {unInputColumnIndex :: ColumnIndex}
  deriving (Generic, Show)

newtype OutputColumnIndex = OutputColumnIndex {unOutputColumnIndex :: ColumnIndex}
  deriving (Generic, Show)

-- All step types for a trace type should have the same number of inputs. When
-- a step type has fewer ``real'' inputs than the total number of inputs,
-- the extra inputs in its links table entries should be wired to a special
-- subexpression id called void. The step type of void has no constraints.
-- The links table entry outputting void has all its inputs set to void.
-- Void's value can legally be set to anything. Each trace type features void.
data StepType = StepType
  { gateConstraints :: PolynomialConstraints,
    lookupArguments :: LookupArguments Polynomial,
    fixedValues :: FixedValues
  }
  deriving (Generic, Show)

instance Semigroup StepType where
  (StepType a b c) <> (StepType d e f) =
    StepType (a <> d) (b <> e) (c <> f)

instance Monoid StepType where
  mempty = StepType mempty mempty mempty

newtype StepTypeId = StepTypeId {unStepTypeId :: Scalar}
  deriving stock (Generic)
  deriving newtype (Eq, Ord, Num, Show)

newtype SubexpressionId = SubexpressionId {unSubexpressionId :: Scalar}
  deriving stock (Generic)
  deriving newtype (Eq, Ord, Num, Show)

newtype InputSubexpressionId = InputSubexpressionId {unInputSubexpressionId :: SubexpressionId}
  deriving stock (Generic)
  deriving newtype (Eq, Ord, Show)

newtype OutputSubexpressionId = OutputSubexpressionId {unOutputSubexpressionId :: SubexpressionId}
  deriving stock (Generic)
  deriving newtype (Eq, Ord, Show)

data SubexpressionLink = SubexpressionLink
  { stepType :: StepTypeId,
    inputs :: [InputSubexpressionId],
    output :: OutputSubexpressionId
  }
  deriving (Eq, Ord, Generic, Show)

newtype ResultExpressionId = ResultExpressionId {unResultExpressionId :: SubexpressionId}
  deriving stock (Generic)
  deriving newtype (Show, Eq, Ord)

newtype CaseNumberColumnIndex = CaseNumberColumnIndex {unCaseNumberColumnIndex :: ColumnIndex}
  deriving stock (Generic)
  deriving newtype (Show)

newtype StepTypeColumnIndex = StepTypeColumnIndex {unStepTypeColumnIndex :: ColumnIndex}
  deriving stock (Generic)
  deriving newtype (Show)

newtype StepIndicatorColumnIndex = StepIndicatorColumnIndex {unStepIndicatorColumnIndex :: ColumnIndex}
  deriving stock (Generic)
  deriving newtype (Show)

newtype NumberOfCases = NumberOfCases {unNumberOfCases :: Scalar}
  deriving stock (Generic)
  deriving newtype (Show)

data TraceType = TraceType
  { columnTypes :: ColumnTypes,
    equalityConstrainableColumns :: EqualityConstrainableColumns,
    equalityConstraints :: EqualityConstraints,
    stepTypes :: Map StepTypeId StepType,
    subexpressions :: Set SubexpressionId,
    links :: Set SubexpressionLink,
    results :: Set ResultExpressionId,
    caseNumberColumnIndex :: CaseNumberColumnIndex,
    stepTypeColumnIndex :: StepTypeColumnIndex,
    stepIndicatorColumnIndex :: StepIndicatorColumnIndex,
    inputColumnIndices :: [InputColumnIndex],
    outputColumnIndex :: OutputColumnIndex,
    numCases :: NumberOfCases,
    rowCount :: RowCount
  }
  deriving (Generic, Show)