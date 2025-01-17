{-# LANGUAGE OverloadedLabels #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Halo2.AIR
  ( toCircuit,
    fromCircuit,
  )
where

import Halo2.Prelude
import Halo2.Types.AIR (AIR (AIR))
import Halo2.Types.Circuit (Circuit (Circuit))
import Halo2.Types.EqualityConstrainableColumns (EqualityConstrainableColumns)
import Halo2.Types.EqualityConstraints (EqualityConstraints)
import Halo2.Types.LookupArguments (LookupArguments)

toCircuit ::
  AIR a ->
  EqualityConstrainableColumns ->
  LookupArguments b ->
  EqualityConstraints ->
  Circuit a b
toCircuit a eqcs lookups eqs =
  Circuit
    (a ^. #columnTypes)
    eqcs
    (a ^. #gateConstraints)
    lookups
    (a ^. #rowCount)
    eqs
    (a ^. #fixedValues)

fromCircuit :: Circuit a b -> AIR a
fromCircuit c =
  AIR
    (c ^. #columnTypes)
    (c ^. #gateConstraints)
    (c ^. #rowCount)
    (c ^. #fixedValues)
