<?php

/**
 * Mahara: Electronic portfolio, weblog, resume builder and social networking
 * Copyright (C) 2010 Catalyst IT Ltd
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/**
 * Reads a Mahara language pack, and outputs a single file in .po format
 * Expects:
 * - Name of a directory containing default English language pack
 * - Name of a directory containing a translation
 * - Filename to write PO entries
 * The Mahara filename & language key are written to the reference and
 * msgctxt lines of each PO entry.  Strings found in the translation but
 * not in the English langpack are ignored.
 */

define('L_START', 0);
define('L_STRING', 1);
define('L_LBRACKET', 2);
define('L_STRINGKEY', 3);
define('L_RBRACKET', 4);
define('L_EQUALS', 5);
define('L_STRINGVALUE', 6);
define('L_HEREDOCSTRING', 7);
define('L_HEREDOCEND', 8);
define('L_SEMI', 9);
define('L_STARTPLURAL', 10);
define('L_NEXTPLURAL', 11);
define('L_PLURALKEY', 12);
define('L_PLURALDOUBLEARROW', 13);

// Reading default en.utf8 langpack files fails unless INTERNAL is defined
define('INTERNAL', 1);

function phptopo($en_strings, $fileid, $in, $pot) {
    $rawtokens = token_get_all(file_get_contents($in));

    $po = "\n";
    $state = L_START;

    foreach ($rawtokens as $t) {
        if ($t[0] == T_WHITESPACE) {
            continue;
        }
        if ($state == L_START && $t[0] == T_STRING && $t[1] == 'defined') {
            $state = L_STRING;
        }
        elseif (($state == L_STRING || $state == L_START) && $t[0] == T_VARIABLE && $t[1] == '$string') {
            $keys = array();
            $values = array();
            $plurals = array();
            $state = L_LBRACKET;
        }
        elseif ($state == L_LBRACKET && $t == '[') {
            $state = L_STRINGKEY;
        }
        elseif ($state == L_STRINGKEY && $t[0] == T_CONSTANT_ENCAPSED_STRING) {
            $keys[] = $t[1];
            $state = L_RBRACKET;
        }
        elseif ($state == L_RBRACKET && $t == ']') {
            $state = L_EQUALS;
        }
        elseif ($state == L_EQUALS && $t == '=') {
            $state = L_STRINGVALUE;
        }
        elseif ($state == L_STRINGVALUE && $t[0] == T_VARIABLE && $t[1] == '$string') {
            $state = L_LBRACKET;
        }
        elseif ($state == L_STRINGVALUE && $t[0] == T_CONSTANT_ENCAPSED_STRING) {
            $values[] = $t[1];
            $state = L_SEMI;
        }
        elseif ($state == L_STRINGVALUE && $t[0] == T_START_HEREDOC) {
            unset($heredoc);
            $state = L_HEREDOCSTRING;
        }
        elseif ($state == L_STRINGVALUE && $t[0] == T_ARRAY) {
            $state = L_STARTPLURAL;
        }
        elseif ($state == L_STARTPLURAL && $t[0] == '(') {
            $pluralindex = null;
            $state = L_PLURALKEY;
        }
        elseif ($state == L_PLURALKEY && $t[0] == T_LNUMBER) {
            $pluralindex = $t[1];
            $state = L_PLURALDOUBLEARROW;
        }
        elseif ($state == L_PLURALKEY && $t[0] == T_CONSTANT_ENCAPSED_STRING) {
            if (!is_null($pluralindex)) {
                $plurals[$pluralindex] = $t[1];
            }
            else {
                $plurals[] = $t[1];
            }
            $state = L_NEXTPLURAL;
        }
        elseif ($state == L_PLURALDOUBLEARROW && $t[0] == T_DOUBLE_ARROW) {
            $state = L_PLURALKEY;
        }
        elseif ($state == L_NEXTPLURAL && $t[0] == ',') {
            $pluralindex = null;
            $state = L_PLURALKEY;
        }
        elseif ($state == L_NEXTPLURAL && $t[0] == ')' || $state == L_PLURALKEY && $t[0] == ')') {
            $state = L_SEMI;
        }
        elseif ($state == L_HEREDOCSTRING && $t[0] == T_ENCAPSED_AND_WHITESPACE) {
            $heredoc = $t[1];
            $state = L_HEREDOCEND;
        }
        elseif ($state == L_HEREDOCEND && $t[0] == T_END_HEREDOC) {
            $state = L_SEMI;
        }
        elseif ($state == L_SEMI && $t[0] == '.') {
            $state = L_STRINGVALUE;
        }
        elseif ($state == L_SEMI && $t == ';') {
            if (isset($heredoc)) {
                $hdstring = $heredoc;
                unset($heredoc);
            }
            else {
                $hdstring = null;
            }

            foreach ($keys as $key) {
                eval('$k = ' . $key . ';');

                if (!isset($en_strings[$k])) {
                    // The file is translating a string we don't care about
                    continue;
                }

                if (is_string($en_strings[$k]) && strlen($en_strings[$k]) < 1) {
                    // An empty string doesn't need translation
                    continue;
                }

                if (is_array($en_strings[$k])) {
                    // Plural forms: English should always have two
                    if (count($en_strings[$k]) != 2) {
                        continue;
                    }
                    if (!isset($en_strings[$k][0]) || !isset($en_strings[$k][1])) {
                        continue;
                    }
                    // Plurals must be translated as plurals
                    if (empty($plurals)) {
                        continue;
                    }
                }

                $po .= "\n\n#: $fileid $k";
                $po .= "\nmsgctxt \"$fileid $k\"";

                if (is_array($en_strings[$k])) {
                    $po .= "\nmsgid \"" . addcslashes($en_strings[$k][0], "\\\"\r\n") . '"';
                    $po .= "\nmsgid_plural \"" . addcslashes($en_strings[$k][1], "\\\"\r\n") . '"';
                    if ($pot) {
                        $po .= "\nmsgstr[0] \"\"";
                        $po .= "\nmsgstr[1] \"\"";
                    }
                    else {
                        foreach ($plurals as $pindex => $qstring) {
                            $po .= "\nmsgstr[$pindex] \"";
                            eval('$s = ' . $qstring . ';');
                            $po .= addcslashes($s, "\\\"\r\n");
                            $po .= '"';
                        }
                    }
                }
                else {
                    $po .= "\nmsgid \"" . addcslashes($en_strings[$k], "\\\"\r\n") . '"';
                    if ($pot) {
                        $po .= "\nmsgstr \"\"";
                    }
                    else {
                        $po .= "\nmsgstr \"";
                        if (!is_null($hdstring)) {
                            $po .= addcslashes($hdstring, "\\\"\r\n");
                        }
                        else {
                            foreach ($values as $qstring) {
                                eval('$s = ' . $qstring . ';');
                                $po .= addcslashes($s, "\\\"\r\n");
                            }
                        }
                        $po .= '"';
                    }
                }
                unset($en_strings[$k]); // Avoid duplicates
            }
            $state = L_STRING;
        }
        elseif ($state == L_STRING && $t[0] == T_CLOSE_TAG) {
            break;
        }
        elseif ($state != L_START && $state != L_STRING) {
            $state = L_STRING;
        }

    }

    return $po;
}

function get_langfile_list(&$list, $dir) {
    if (is_dir($dir)) {
        if ($dh = opendir($dir)) {
            while (($file = readdir($dh)) !== false) {
                if ($file != '.' && $file != '..') {
                    $path = $dir . '/' . $file;
                    if (is_dir($path)) {
                        get_langfile_list($list, $path);
                    }
                    else if (is_file($path) && is_readable($path)) {
                        $list[] = $path;
                    }
                }
            }
            closedir($dh);
        }

    }
}

$en_dir   = $argv[1];
$source   = $argv[2];
$destfile = $argv[3];

$destdir = dirname($destfile);

if (!is_dir($destdir)) {
    mkdir($destdir, 0755, true);
}
if (file_exists($destfile)) {
    unlink($destfile);
}

$sourcefiles = array();
get_langfile_list($sourcefiles, $source);

$version = 'mahara';
if (preg_match('/master\.pot$/', $destfile)) {
    $version .= '-trunk';
}
else if (preg_match('/(\d[0-9\.]+)_STABLE\.pot$/', $destfile, $matches)) {
    $version .= '-' . $matches[1];
}
if ($version == 'mahara') {
    if (preg_match('/\/master$/', $source)) {
        $version .= '-trunk';
    }
    else if (preg_match('/\/(\d[0-9\.]+)_STABLE$/', $source, $matches)) {
        $version .= '-' . $matches[1];
    }
}

    $header = '
msgid ""
msgstr ""
"Project-Id-Version: ' . $version . '\n"
"Report-Msgid-Bugs-To: https://bugs.launchpad.net/mahara\n"';

if ($pot = preg_match('/.pot$/', $destfile)) {
    $header .= '
"POT-Creation-Date: ' . date('Y-m-d H:iO') . '\n"
"PO-Revision-Date: YYYY-MM-DD HH:MM+ZZZZ\n"
"Last-Translator: FULL NAME <EMAIL@ADDRESS>\n"
"Language-Team: LANGUAGE <EMAIL@ADDRESS>\n"';
}
else {
    $header .= '
"PO-Revision-Date: ' . date('Y-m-d H:iO') . '\n"
"Last-Translator: \n"
"Language: \n"
"Language-Team: \n"';
}

    $header .= '
"MIME-Version: 1.0\n"
"Content-Type: text/plain; charset=utf-8\n"
"Content-Transfer-Encoding: 8bit\n"

';

file_put_contents($destfile, $header, FILE_APPEND);

if (!empty($sourcefiles)) {
    sort($sourcefiles);
    foreach ($sourcefiles as $sourcefile) {

        $langfile = substr($sourcefile, strlen($source) + 1);
        $en_file = preg_replace('/lang\/[a-zA-Z_]+\.utf8\//', 'lang/en.utf8/', $langfile);

        if (!file_exists($en_dir . '/' . $en_file)) {
            continue;
        }

        $po = null;

        if (preg_match('/lang\/.*\.utf8\/.*\.html$/', $langfile)) {
            $po .= "\n\n#: $en_file";
            $po .= "\nmsgctxt \"$en_file\"";
            $content = mb_ereg_replace("\r\n", "\n", file_get_contents($en_dir . '/' . $en_file));
            $po .= "\nmsgid \"" . addcslashes($content, "\\\"\r\n") . '"';
            $po .= "\nmsgstr \"";
            if (!$pot) {
                $content = mb_ereg_replace("\r\n", "\n", file_get_contents($sourcefile));
                $po .= addcslashes($content, "\\\"\r\n");
            }
            $po .= '"';
        }

        if (preg_match('/lang\/.*\.utf8\/.*\.php$/', $langfile)) {
            $string = array();
            include ($en_dir . '/' . $en_file); // Fills $string
            $po = phptopo($string, $en_file, $sourcefile, $pot);
        }

        if ($po) {
            file_put_contents($destfile, $po, FILE_APPEND);
        }
    }
}

file_put_contents($destfile, "\n", FILE_APPEND);