{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Halo2.Types.LookupArguments
  ( LookupArguments (LookupArguments),
  )
where

import Halo2.Prelude
import Halo2.Types.LookupArgument (LookupArgument)

newtype LookupArguments a = LookupArguments {getLookupArguments :: Set (LookupArgument a)}
  deriving (Eq, Ord, Show, Generic, Semigroup, Monoid)
