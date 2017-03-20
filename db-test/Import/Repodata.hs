-- Copyright (C) 2016-2017 Red Hat, Inc.
--
-- This library is free software; you can redistribute it and/or
-- modify it under the terms of the GNU Lesser General Public
-- License as published by the Free Software Foundation; either
-- version 2.1 of the License, or (at your option) any later version.
--
-- This library is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- Lesser General Public License for more details.
--
-- You should have received a copy of the GNU Lesser General Public
-- License along with this library; if not, see <http://www.gnu.org/licenses/>.

{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Import.Repodata(loadFromFile,
                       loadFromURL)
 where

import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as C8
import           Data.Conduit((.|), runConduitRes)
import qualified Data.Text as T
import           Network.HTTP.Conduit(path)
import           Network.HTTP.Simple(Request)
import           System.FilePath((</>), takeDirectory)
import           Text.XML(Document, sinkDoc)
import           Text.XML.Cursor
import           Text.XML.Stream.Parse(def)

import           Import.Conduit(getFromFile, getFromURL, ungzipIfCompressed)
import qualified Import.RPM as RPM

extractLocations :: Document -> [String]
extractLocations doc = let
    cursor = fromDocument doc
 in
    -- Find all <location href=""> elements and return the href's value.  laxElement
    -- means we ignore case and ignore namespacing.  Otherwise we need to take into
    -- account the namespace given in the primary.xml.
    map T.unpack $
        cursor $// laxElement "location"
               >=> hasAttribute "href"
               >=> attribute "href"

loadFromURL :: FilePath -> Request -> IO ()
loadFromURL db metadataRequest = do
    let (basePath, _) = BS.breakSubstring "repodata/" (path metadataRequest)
    locations <- map (\p -> metadataRequest { path=BS.concat [basePath, C8.pack p] }) <$> extractLocations <$> runConduitRes (readMetadataPipeline metadataRequest)
    mapM_ (RPM.loadFromURL db) locations
 where
    readMetadataPipeline request = getFromURL request .| ungzipIfCompressed (C8.unpack $ path request) .| sinkDoc def

loadFromFile :: FilePath -> String -> IO ()
loadFromFile db metadataPath = do
    locations <- map (takeDirectory metadataPath </>) <$> extractLocations <$> runConduitRes (readMetadataPipeline metadataPath)
    mapM_ (RPM.loadFromFile db) locations
 where
    readMetadataPipeline p = getFromFile p .| ungzipIfCompressed p .| sinkDoc def