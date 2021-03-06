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

module Export.Utils(runHacks)
 where

import Control.Conditional(whenM)
import Data.List(intercalate)
import Data.List.Split(splitOn)
import System.Directory(createDirectoryIfMissing, doesFileExist, renameFile)
import System.FilePath((</>))
import System.Process(callProcess)

import Paths_db(getDataFileName)

-- | Run filesystem hacks needed to make a directory tree bootable
runHacks :: FilePath -> IO ()
runHacks exportPath = do
    -- set a root password
    -- pre-crypted from "redhat"
    shadowRecs <- map (splitOn ":") <$> lines <$> readFile (exportPath </> "etc" </> "shadow")
    let newRecs = map (\rec -> if head rec == "root" then
                                ["root", "$6$3VLMX3dyCGRa.JX3$RpveyimtrKjqcbZNTanUkjauuTRwqAVzRK8GZFkEinbjzklo7Yj9Z6FqXNlyajpgCdsLf4FEQQKH6tTza35xs/"] ++ drop 2 rec
                               else
                                rec) shadowRecs
    writeFile (exportPath </> "etc" </> "shadow.new") (unlines $ map (intercalate ":") newRecs)
    renameFile (exportPath </> "etc" </> "shadow.new") (exportPath </> "etc" </> "shadow")

    -- create an empty machine-id
    writeFile (exportPath </> "etc" </> "machine-id") ""

    -- Install a sysusers.d config file, and run systemd-sysusers to implement it
    let sysusersDir = exportPath </> "usr" </> "lib" </> "sysusers.d"
    createDirectoryIfMissing True sysusersDir
    getDataFileName "sysusers-default.conf" >>= readFile >>= writeFile (sysusersDir </> "weldr.conf")
    callProcess "systemd-sysusers" ["--root", exportPath]

    -- Install a tmpfiles.d config file
    let tmpfilesDir = exportPath </> "usr" </> "lib" </> "tmpfiles.d"
    createDirectoryIfMissing True tmpfilesDir
    getDataFileName "tmpfiles-default.conf" >>= readFile >>= writeFile (tmpfilesDir </> "weldr.conf")

    -- Create a fstab stub
    writeFile (exportPath </> "etc" </> "fstab") "LABEL=composer / ext2 defaults 0 0"

    -- EXTRA HACKY: turn off mod_ssl
    let sslConf = exportPath </> "etc" </> "httpd" </> "conf.d" </> "ssl.conf"
    whenM (doesFileExist sslConf)
          (renameFile sslConf (sslConf ++ ".off"))
