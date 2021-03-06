-- Copyright (C) 2017 Red Hat, Inc.
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
{-# LANGUAGE RankNTypes #-}

module Export.Tar(tarSink)
 where

import qualified Codec.Archive.Tar as Tar
import           Control.Monad.IO.Class(MonadIO, liftIO)
import           Data.ByteString.Lazy(writeFile)
import           Data.Conduit(Consumer)
import qualified Data.Conduit.List as CL
import           Prelude hiding(writeFile)

tarSink :: MonadIO m => FilePath -> Consumer Tar.Entry m ()
tarSink out_path = do
    entries <- CL.consume
    liftIO $ writeFile out_path (Tar.write entries)
