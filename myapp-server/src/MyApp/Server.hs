{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeOperators #-}

module MyApp.Server (main, app) where

import Control.Concurrent.STM (TVar, atomically, modifyTVar', newTVarIO, readTVar, readTVarIO)
import Control.Monad.IO.Class (liftIO)
import Network.Wai.Application.Static (defaultWebAppSettings, staticApp)
import Network.Wai.Handler.Warp (run)
import Network.Wai.Middleware.Cors (simpleCors)
import Network.Wai.Middleware.Gzip (def, gzip)
import Servant
import System.Environment (lookupEnv)

import MyApp.API (CounterState (..), Greeting (..))

type API =
       "api" :> "hello" :> Get '[JSON] Greeting
  :<|> "api" :> "counter" :> Get '[JSON] CounterState
  :<|> "api" :> "counter" :> "increment" :> Post '[JSON] CounterState
  :<|> Raw

server :: TVar Int -> FilePath -> Server API
server ref staticDir =
       hello
  :<|> readCounter
  :<|> incrementCounter
  :<|> Tagged (staticApp (defaultWebAppSettings staticDir))
  where
    hello = pure (Greeting "Hello from Servant + Miso!")

    readCounter = CounterState <$> liftIO (readTVarIO ref)

    incrementCounter = do
      n <- liftIO . atomically $ do
        modifyTVar' ref (+ 1)
        readTVar ref
      pure (CounterState n)

app :: TVar Int -> FilePath -> Application
app ref dir = gzip def (simpleCors (serve (Proxy @API) (server ref dir)))

main :: IO ()
main = do
  ref <- newTVarIO 0
  dir <- maybe "myapp-ui/static" id <$> lookupEnv "MYAPP_STATIC_DIR"
  port <- maybe 8080 read <$> lookupEnv "MYAPP_PORT"
  putStrLn $ "myapp-server listening on http://localhost:" <> show port
  putStrLn $ "  static dir: " <> dir
  run port (app ref dir)
