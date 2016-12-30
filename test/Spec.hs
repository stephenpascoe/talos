{-# LANGUAGE QuasiQuotes #-}

module Main where

import Test.Hspec
import Test.QuickCheck
import Test.QuickCheck.Instances

import Lib
import Types
import Types.Arbitrary
import Sql.Encoder

import Data.Aeson as A
import qualified Data.Text as T
import qualified Data.Bson as B
import Text.RawString.QQ
import Data.Maybe


fromJSON_eq :: A.Value -> QueryExpr -> Bool
fromJSON_eq obj expr = fromJSON obj == A.Success expr


prop_eq1 :: T.Text -> T.Text -> Bool
prop_eq1 a b = fromJSON_eq (object [ a .= b ]) (ExprConstr $ OpEQ a (B.String b))


prop_eq2 :: T.Text -> T.Text -> Bool
prop_eq2 a b = fromJSON_eq (object [ a .= object [ "$eq" .= b ] ]) (ExprConstr $ OpEQ a (B.String b))


prop_and1 :: T.Text -> T.Text -> T.Text -> T.Text -> Bool
prop_and1 a b c d = fromJSON_eq (object [ "$and" .= [object [a .= b], object [c .= d]] ])
                                (ExprAND [ExprConstr $ OpEQ a (B.String b), ExprConstr $ OpEQ c (B.String d)])


prop_sql_serialise :: FindExpr -> Bool
prop_sql_serialise expr = isJust $ findToSqlText expr

prop_query_serialise :: QueryExpr -> Bool
prop_query_serialise expr = isJust $ queryToSQL expr

eg1 = [r|{"$and": [
           {"tracking_id.asic_id": "AAAA"},
           {"membrane_summary": {"$exists": true}},
           {"$or": [
             {"context_tags": {"$exists": false}},
             {"$and": [
               {"context_tags.department": "qc"},
               {"context_tags.experiment_type": "full_pore_insertion"}
             ]}
           ]}
         ]}
|]

main :: IO ()
main = hspec $ do
  describe "MongoDB JSON query language" $ do
    it "encodes default equality" $ property prop_eq1
    it "encodes equality with $eq" $ property prop_eq2
    it "encodes logical and" $ property prop_and1
    it "Any query expression will encode to SQL AST" $ property prop_query_serialise
    it "Any find expression will encode to SQL" $ property prop_sql_serialise
