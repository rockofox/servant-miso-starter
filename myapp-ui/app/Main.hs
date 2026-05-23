{-# LANGUAGE CPP #-}

module Main where

import Miso (defaultEvents, startApp)
import MyApp.UI.App (app)

#ifdef WASM
foreign export javascript "hs_start" main :: IO ()
#endif

main :: IO ()
main = startApp defaultEvents app
