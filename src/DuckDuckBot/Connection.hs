module DuckDuckBot.Connection (
    Connection,
    newConnection,
    closeConnection,
    putMessageConnection,
    ConnectionReader,
    runConnectionReader,
    getMessage
) where

import qualified Data.ByteString as B
import qualified Data.ByteString.UTF8 as UB

import qualified Network.Connection as C
import qualified Network.IRC as IRC
import qualified Network.IRC.Parser as IRCP

import Control.Applicative
import Control.Monad.State
import Control.Monad.Reader
import Control.Exception

import Data.Attoparsec.ByteString hiding (try)

data Connection = Connection { getConnection :: C.Connection }

newConnection :: String -> Int -> Bool -> IO Connection
newConnection server port tls = do
    ctx <- C.initConnectionContext
    let tlsSettings = if tls then Just (C.TLSSettingsSimple False False True) else Nothing
        params = C.ConnectionParams {
                                    C.connectionHostname = server,
                                    C.connectionPort = fromIntegral port,
                                    C.connectionUseSecure = tlsSettings,
                                    C.connectionUseSocks = Nothing
                                  }

    c <- C.connectTo ctx params
    return (Connection c)

closeConnection :: Connection -> IO ()
closeConnection c = C.connectionClose (getConnection c)

putMessageConnection :: Connection -> IRC.Message -> IO ()
putMessageConnection c m = do
    -- Catch all possible exceptions when evaluating encoding
    -- as a IRC message and make sure we have a
    evS <- liftIO (try (evaluate (IRC.encode m)) :: IO (Either SomeException UB.ByteString))
    case evS of
        Right s -> do
                        C.connectionPut (getConnection c) (s `B.append` "\r\n")
                        putStrLn ("> " ++ UB.toString s)
        Left e  -> liftIO $ print ("Exception in putMessageConnection: " ++ show e)

type ConnectionReader m = StateT B.ByteString (ReaderT Connection m)
runConnectionReader :: (MonadIO m) => Connection -> ConnectionReader m a -> m a
runConnectionReader c f = runReaderT (evalStateT f B.empty) c

getMessage :: (MonadIO m) => ConnectionReader m IRC.Message
getMessage = do
    c <- ask
    t <- get
    r <- liftIO $ parseWith (C.connectionGetChunk (getConnection c)) messagecrlf t

    -- If we finished a parse, return the message, otherwise
    -- recurse to try again
    case r of
        (Done t' msg)    -> do
                                put t'
                                liftIO $ putStrLn ("< " ++ UB.toString (IRC.encode msg)) >> return msg
        (Fail t' _ err)  -> do
                                liftIO $ putStrLn ("ERROR: Parsing IRC message failed " ++ err)
                                put t'
                                getMessage
        _                -> getMessage

messagecrlf :: Parser IRC.Message
messagecrlf = IRC.Message <$>
                     optionMaybe (IRCP.prefix <* IRCP.spaces)
                     <*> IRCP.command
                     <*> many (IRCP.spaces *> IRCP.parameter)
                     <* string "\r\n"
    where
        optionMaybe p = option Nothing (Just <$> p)
