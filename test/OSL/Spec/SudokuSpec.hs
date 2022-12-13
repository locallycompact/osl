{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedLabels #-}
{-# LANGUAGE OverloadedStrings #-}

module OSL.Spec.SudokuSpec (spec) where

import Control.Lens ((^.))
import qualified Data.Map as Map
import Data.Text (pack)
import OSL.ArgumentForm (getArgumentForm)
import OSL.Parse (parseContext)
import OSL.SimplifyType (simplifyType)
import OSL.Tokenize (tokenize)
import OSL.Types.ArgumentForm (ArgumentForm (ArgumentForm), StatementType (StatementType), WitnessType (WitnessType))
import OSL.Types.OSL (ValidContext, ContextType (Global), Declaration (Defined), Name (Sym), Type (Product, NamedType, Fin, F))
import OSL.ValidateContext (validateContext)
import Test.Syd (Spec, describe, liftIO, expectationFailure, it, shouldBe)
import Text.Parsec (SourcePos)

spec :: Spec
spec =
  describe "Sudoku" $ do
    let sudokuSpecFile = "examples/sudoku.osl"
    sudokuSpecTxt <- pack <$> liftIO (readFile sudokuSpecFile)
    case tokenize sudokuSpecFile sudokuSpecTxt of
      Right toks ->
        case parseContext sudokuSpecFile toks of
          Right rawCtx ->
            case validateContext rawCtx of
              Right validCtx ->
                spec' validCtx
              Left err -> liftIO . expectationFailure $
                "invalid context: " <> show err
          Left err -> liftIO . expectationFailure $
            "parse error: " <> show err
      Left err -> liftIO . expectationFailure $
        "tokenizing error: " <> show err

spec' :: ValidContext 'Global SourcePos -> Spec
spec' c = do
  argumentFormSpec c

complexStatementType :: Type ()
complexStatementType =
  Product () (NamedType () (Sym "Problem")) (Fin () 1)

simpleStatementType :: Type ()
simpleStatementType = NamedType () (Sym "Problem")

complexWitnessType :: Type ()
complexWitnessType =
  Product ()
    (NamedType () (Sym "Solution"))
    (Product ()
      (F () Nothing
        (NamedType () (Sym "Cell"))
        (Product () (Fin () 1) (Fin () 1)))
      (Product ()
        (Product ()
          (F () Nothing
            (NamedType () (Sym "Row"))
            (F () Nothing
              (NamedType () (Sym "Value"))
              (Product ()
                (NamedType () (Sym "Col"))
                (Fin () 1))))
          (F () Nothing
            (NamedType () (Sym "Col"))
            (F () Nothing
              (NamedType () (Sym "Value"))
              (Product ()
                (NamedType () (Sym "Row"))
                (Fin () 1)))))
        (F () Nothing
          (NamedType () (Sym "Square"))
          (F () Nothing
            (NamedType () (Sym "Value"))
            (Product ()
              (NamedType () (Sym "SquareCell"))
              (Fin () 1))))))

simpleWitnessType :: Type ()
simpleWitnessType =
  Product ()
    (NamedType () (Sym "Solution"))
    (Product ()
      (Product ()
        (F () Nothing
          (NamedType () (Sym "Row"))
          (F () Nothing
            (NamedType () (Sym "Value"))
            (NamedType () (Sym "Col"))))
        (F () Nothing
          (NamedType () (Sym "Col"))
          (F () Nothing
            (NamedType () (Sym "Value"))
            (NamedType () (Sym "Row")))))
      (F () Nothing
        (NamedType () (Sym "Square"))
        (F () Nothing
          (NamedType () (Sym "Value"))
          (NamedType () (Sym "SquareCell")))))

argumentFormSpec :: ValidContext 'Global SourcePos -> Spec
argumentFormSpec c = do
  it "has the correct argument form" $
    case Map.lookup (Sym "problemIsSolvable")
           (c ^. #unValidContext) of
      Just (Defined t x) -> do
        getArgumentForm c t x `shouldBe`
          Right (ArgumentForm
                   (StatementType complexStatementType)
                   (WitnessType complexWitnessType))
      _ ->
        liftIO . expectationFailure $
          "problemIsSolvable definition not found"

  it "has the correct simplified statement type" $
    simplifyType complexStatementType `shouldBe` Just simpleStatementType

  it "has the correct simplified witness type" $
    simplifyType complexWitnessType `shouldBe` Just simpleWitnessType
