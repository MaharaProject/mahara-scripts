#!/usr/bin/php
<?php
// Include the library
include('simple_html_dom.php');
// Include default mapping actions to steps
include('action2step.php');

define('DEFAULT_DELAY', '5000');    // in miliseconds
$delay = DEFAULT_DELAY;

if (count($argv) != 3) {
    die("Usage: $argv[0] <selenium test suite html file> <output dir>\n");
}
$path2testsuite = $argv[1];
$basedir = dirname($path2testsuite);
$outputdir = $argv[2];

// Retrieve the test cases from the testsuite html
$testsuitehtml = file_get_html($path2testsuite);

//foreach($testsuitehtml->find('td strong', 1) as $title)$target
echo "Converting the test suite '" . $testsuitehtml->find('td strong', 0)->innertext . "'\n";

// Find all test cases and convert them
foreach($testsuitehtml->find('a') as $e) {
    $path2testcase = $basedir . '/' . $e->href;
    $testcasehtml = file_get_html($path2testcase);
    $outputstr = <<<EOT
Feature: $e->innertext
    @javascript\n
EOT;
    if ($e->innertext != 'Edit_Resume') continue;    // for code testing
    $step = 0;
    foreach($testcasehtml->find('tr') as $r) {
        $step++;
        $action = $r->find('td');
        if (!isset($action[0])) {
            continue;
        }
        $command = $action[0]->innertext;
        $target  = isset($action[1]) ? $action[1]->innertext : '';
        $value   = isset($action[2]) ? $action[2]->innertext : '';
        if ($step == 1) {
            if (empty($target) && empty($value)) {
                $outputstr .= "    Scenario: $command\n";
                continue;
            }
            else {
                $outputstr .= "    Scenario: $e->innertext\n";
            }
        }
        $outputstr .= convert2step($command, $target, $value);
    }
    echo $outputstr;
}

function convert2step($command, $target, $value) {
    global $action2step, $delay;

    $result = "        ";
    $target = parse_target($target);
    $value = "\"$value\"";
    list($action, $postfix) = parse_assert_command($command);
    if ($action === false) {
        if (!empty($target) && preg_match('/("named"|css"|"xpath")/', $target) === 0) {
            $target = "\"#$target\" \"css\"";
        }
        switch ($command) {
            case 'open':
                if (empty($target)) {
                    $target = '/index.php';
                }
                break;
            case 'setSpeed':
                if (!empty($target)) {
                    $delay = intval($target);
                }
                else {
                    $delay = DEFAULT_DELAY;
                }
                return '';
            default:
                break;
        }
        if (isset($action2step[$command])) {
            eval("\$result .= \"$action2step[$command]\";");
        }
    }
    else {
        if (isset($action2step[$action])) {
            $result .= $action2step[$action];
        }
        if ($postfix !== 'TextPresent') {
            // If $target is an element, convert it to css locator
            if (preg_match('/"css"/', $target) === 0) {
                $target = "\"#$target\" \"css\"";
            }
        }
        switch ($postfix) {
            case 'Title':
                $result .= " $value in the title";
                break;
            case 'NotTitle':
                $result .= " not $value in the title";
                break;
            case 'Table':
                $result .= " $value in the table cell $target";
                break;
            case 'NotTable':
                $result .= " not $value in the table cell $target";
                break;
            case 'NotText':
            case 'NotValue':
                $result .= " not $value";
                if (!empty($target)) {
                    $result .= " in the element $target";
                }
                break;
            case 'TextPresent':
                $result .= " \"$target\"";
                break;
            case 'Visible':
            case 'ElementPresent':
                $result .= " the element $target";
                break;
            default:
                $result .= " $value";
                if (!empty($target)) {
                    $result .= " in the element $target";
                }
                break;
        }
    }
    $result .= "\n";
    return $result;
}

function parse_assert_command($command) {
    $assertactions = array('waitFor', 'verify', 'assert');
    foreach ($assertactions as $a) {
        if (strpos($command, $a) !== false) {
            return (array($a, substr($command, strlen($a))));
        }
    }
    return array(false, false);
}

/**
 * returns the selector and locator of a given target
 * 
 * @param string $target
 * @param string '"$locator" "$selector"'
 *     $selector: type of an element = named|css|xpath
 *     $locator: array($type, $text) if $selector = named
 *             : $cssquery if $selector = css
 *             : $xpathquery if $selector = xpath
 */
function parse_target($target) {
    if (empty($target)) {
        return "";
    }
    if (preg_match('/^xpath=(.+)$/', $target, $matches) === 1
        || preg_match('/^\/\/(.+)$/', $target, $matches) === 1) {
        return "\"$matches[0]\" \"xpath\"";
    }
    if (preg_match('/^css=(.+)$/', $target, $matches) === 1) {
        return "\"$matches[1]\" \"css\"";
    }
    if (preg_match('/^id=(.+)$/', $target, $matches) === 1) {
        return "\"#$matches[1]\" \"css\"";
    }
    if (preg_match('/^(\w+)=(.+)$/', $target, $matches) === 1) {
        return "\"$target\" \"named\"";
    }
    return $target;
}
?>
