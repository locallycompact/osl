module OSL.Types.TranslationContext
  ( TranslationContext (..)
  , Mapping (..)
  , LeftMapping (..)
  , RightMapping (..)
  , ChoiceMapping (..)
  , LengthMapping (..)
  , ValuesMapping (..)
  , KeysMapping (..)
  , KeyIndicatorMapping (..)
  ) where


import Data.Map (Map)

import qualified OSL.Types.OSL as OSL
import qualified OSL.Types.Sigma11 as S11


newtype TranslationContext =
  TranslationContext
  { unTranslationContext
      :: Map OSL.Name Mapping }


data Mapping =
    ScalarMapping
    S11.Name
  | ProductMapping
    LeftMapping
    RightMapping
  | CoproductMapping
    ChoiceMapping
    LeftMapping
    RightMapping
  | ListMapping
    LengthMapping
    ValuesMapping
  | MapMapping
    LengthMapping
    KeysMapping
    KeyIndicatorMapping
    ValuesMapping


newtype LeftMapping = LeftMapping { unLeftMapping :: Mapping }


newtype RightMapping = RightMapping { unRightMapping :: Mapping }


newtype ChoiceMapping = ChoiceMapping { unChoiceMapping :: S11.Name }


newtype LengthMapping = LengthMapping { unLengthMapping :: S11.Name }


newtype ValuesMapping = ValuesMapping { unValuesMapping :: Mapping }


newtype KeysMapping = KeysMapping { unKeysMapping :: Mapping }


newtype KeyIndicatorMapping = KeyIndicatorMapping { unKeyIndicatorMapping :: S11.Name }
