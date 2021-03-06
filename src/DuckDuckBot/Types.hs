{-# LANGUAGE DeriveDataTypeable #-}

module DuckDuckBot.Types (
    Env (..),
    Config (..),
    InMessage (..),
    OutMessage (..),
    MessageHandler,
    MessageHandlerEnv (..),
    MessageHandlerEnvReader,
    MessageHandlerSendMessage,
    MessageHandlerMetadata (..),
    TimeoutException(..),
    module DuckDuckBot.Connection
) where

import DuckDuckBot.Connection

import Control.Monad.Reader

import qualified Network.IRC as IRC
import Control.Concurrent.STM.TMChan

import Data.Typeable
import Control.Exception

import qualified Network.HTTP.Client as HTTP

data Env = Env {
    envConfig      :: Config,
    envConnection  :: Connection,
    envInChan      :: TMChan InMessage, -- This is duplicated to all message handlers
    envOutChan     :: TMChan OutMessage
}

data Config = Config {
    cfgServer           :: String,
    cfgPort             :: Int,
    cfgNick             :: String,
    cfgNickServPassword :: Maybe String,
    cfgChannel          :: String,
    cfgUseSsl           :: Bool,
    cfgAuthPassword     :: Maybe String
} deriving (Show)

type MessageHandlerEnvReader = ReaderT MessageHandlerEnv
data MessageHandlerEnv = MessageHandlerEnv {
    messageHandlerEnvServer  :: String,
    messageHandlerEnvNick    :: String,
    messageHandlerEnvChannel :: String,
    messageHandlerEnvIsAuthUser :: IRC.Prefix -> IO Bool,
    messageHandlerEnvHttpManager :: HTTP.Manager
}

-- More messages to be added here if we ever have
-- to tell our command handlers to do anything
data InMessage  = InIRCMessage IRC.Message
    deriving (Show)
data OutMessage = OutIRCMessage IRC.Message
    deriving (Show)

type MessageHandler = TMChan InMessage -> TMChan OutMessage -> MessageHandlerEnvReader IO ()
type MessageHandlerSendMessage = IRC.Message -> IO ()

data MessageHandlerMetadata = MessageHandlerMetadata {
    messageHandlerMetadataName :: String,
    messageHandlerMetadataCommands :: [String],
    messageHandlerMetadataHandler :: MessageHandler
}

data TimeoutException = TimeoutException
    deriving (Typeable, Show)

instance Exception TimeoutException

