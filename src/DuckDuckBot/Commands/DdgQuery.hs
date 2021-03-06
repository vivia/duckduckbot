module DuckDuckBot.Commands.DdgQuery
    ( query
    , simpleQuery
    , Results(..)
    , Result(..)
    , Icon(..)
    ) where

import Data.Aeson hiding (Result)

import qualified Data.ByteString.UTF8 as UB

import qualified Network.HTTP.Client as HTTP
import qualified Network.HTTP.Types.Header as HTTPH
import qualified Network.HTTP.Client.TLS as HTTPS

import Control.Monad
import Control.Applicative
import Control.Exception

data Results = Results {
    resultsAbstract :: String,
    resultsAbstractText :: String,
    resultsAbstractSource :: String,
    resultsAbstractURL :: String,
    resultsImage :: String,
    resultsHeading :: String,
    resultsAnswer :: String,
    resultsRedirect :: String,
    resultsAnswerType :: String,
    resultsDefinition :: String,
    resultsDefinitionSource :: String,
    resultsDefinitionURL :: String,
    resultsRelatedTopics :: [Result],
    resultsResults :: [Result],
    resultsType :: String
} deriving (Show, Eq)

data Result = Result {
    resultResult :: String,
    resultIcon :: Maybe Icon,
    resultFirstURL :: String,
    resultText :: String
} | ResultGroup {
    resultGroupTopics :: [Result],
    resultGroupName :: String
} deriving (Show, Eq)

data Icon = Icon {
    iconURL :: String,
    iconHeight :: Int,
    iconWidth :: Int
} deriving (Show, Eq)

instance FromJSON Results where
    parseJSON (Object v) = Results <$>
                                v .: "Abstract" <*>
                                v .: "AbstractText" <*>
                                v .: "AbstractSource" <*>
                                v .: "AbstractURL" <*>
                                v .: "Image" <*>
                                v .: "Heading" <*>
                                v .: "Answer" <*>
                                v .: "Redirect" <*>
                                v .: "AnswerType" <*>
                                v .: "Definition" <*>
                                v .: "DefinitionSource" <*>
                                v .: "DefinitionURL" <*>
                                v .: "RelatedTopics" <*>
                                v .: "Results" <*>
                                v .: "Type"
    parseJSON _          = mzero

instance FromJSON Result where
    parseJSON (Object v) = Result <$>
                                v .: "Result" <*>
                                v .: "Icon" <*>
                                v .: "FirstURL" <*>
                                v .: "Text"
                            <|>
                           ResultGroup <$>
                                v .: "Topics" <*>
                                v .: "Name"
    parseJSON _          = mzero

instance FromJSON Icon where
    parseJSON (Object v) = Icon <$>
                                v .: "URL" <*>
                                -- Height and width can be an Int or ""
                                intOrString "Height" <*>
                                intOrString "Width"
                           where
                                intOrString s = v .: s <|> (stringTo0 <$> (v .: s))
                                stringTo0 :: String -> Int
                                stringTo0 _ = 0
    parseJSON _          = mzero

query :: HTTP.Manager -> String -> IO (Maybe Results)
query m s = do
    let url = "https://api.duckduckgo.com"
    -- Catch all exceptions here and return nothing
    -- Better do nothing than crashing when we can't do the HTTP request
    handle (\(SomeException e) -> putStrLn ("Exception while handling Ddg request \"" ++ s ++ "\": " ++ show e) >> return Nothing) $ do
        baseReq <- HTTP.parseUrl url
        let headers = (HTTPH.hConnection, "Keep-Alive") : HTTP.requestHeaders baseReq
            req  = HTTP.setQueryString [ ("q", Just (UB.fromString s))
                                       , ("format", Just "json")
                                       , ("no_redirect", Just "1")
                                       , ("no_html", Just "1")
                                       , ("t", Just "ddb")
                                       ]
                                       (baseReq { HTTP.requestHeaders=headers })
        resp <- HTTP.httpLbs req m
        let d = decode (HTTP.responseBody resp)
        HTTP.responseClose resp
        return d

simpleQuery :: String -> IO (Maybe Results)
simpleQuery s = do
    m <- HTTP.newManager HTTPS.tlsManagerSettings
    query m s
