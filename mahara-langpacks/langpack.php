<?php

// Read a Mahara language pack and throw away any php code except
// the string definitions.

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

function clean_lang_file($in, $out) {
    $rawtokens = token_get_all(file_get_contents($in));

    $new = "<?php\n\n";
    $state = L_START;

    foreach ($rawtokens as $t) {
        if ($t[0] == T_WHITESPACE) {
            if ($state != L_STRING) {
                continue;
            }
            $new .= $t[1];
        }
        if ($state == L_START && $t[0] == T_DOC_COMMENT) {
            $new .= $t[1] . "\n\n";
        }
        elseif ($state == L_START && $t[0] == T_STRING && $t[1] == 'defined') {
            $new .= "defined('INTERNAL') || die();";
            $state = L_STRING;
        }
        elseif (($state == L_STRING || $state == L_START) && $t[0] == T_VARIABLE && $t[1] == '$string') {
            $keys = array();
            $values = array();
            $state = L_LBRACKET;
        }
        elseif ($state == L_STRING && $t[0] == T_COMMENT) {
            $new .= $t[1];
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
            foreach ($keys as $key) {
                $new .= "\$string[" . $key . '] = ';
            }
            if (isset($heredoc)) {
                $new .= "<<<EOF\n" . $heredoc . "\nEOF;";
                unset($heredoc);
            }
            else {
                $new .= join("\n    . ", $values) . ";";
            }
            $state = L_STRING;
        }
        elseif ($state == L_STRING && $t[0] == T_CLOSE_TAG) {
            $new .= "?>";
            break;
        }
        elseif ($state != L_START && $state != L_STRING) {
            $state = L_STRING;
        }

    }

    $new .= "\n";

    file_put_contents($out, $new);
}


function clean_help_file($in, $out) {
    $rawtokens = token_get_all(file_get_contents($in));

    $new = '';

    foreach ($rawtokens as $t) {
        if ($t[0] == T_INLINE_HTML) {
            $new .= $t[1];
        }
    }

    file_put_contents($out, $new);
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

$source = $argv[1];
$dest = $argv[2];

$sourcefiles = array();
get_langfile_list($sourcefiles, $source);

if (!empty($sourcefiles)) {
    foreach ($sourcefiles as $sourcefile) {
        $destfile = str_replace($source, $dest, $sourcefile);
        $destdir = dirname($destfile);
        if (!is_dir($destdir)) {
            mkdir($destdir, 0755, true);
        }

        # $filename = str_replace($source, '', $sourcefile);

        if (preg_match('/\/lang\/.*\.utf8\/.*\.php$/', $sourcefile)) {
            clean_lang_file($sourcefile, $destfile);
        }
        else if (preg_match('/utf8\/help\/.*\.html$/', $sourcefile)) {
            clean_help_file($sourcefile, $destfile);
        }
        else if (preg_match('/\/js\/tinymce.*\/langs\/.*\.js$/', $sourcefile)) {
            copy($sourcefile, $destfile);
        }
    }
}
