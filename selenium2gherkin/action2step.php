<?php
// Define the mapping selenium actions to Mink gherkin steps
$action2step = array(
    'open'                 => 'Given I am on $target',
    'click'                => 'When I click on $target',
    'clickAndWait'         => 'When I click on $target',
    'check'                => 'When I check $target',
    'type'                 => 'When I fill in $target with $value',
    'select'               => 'When I select $target',
    'store'                => 'When I store $target with $value',
    'verify'               => 'Then I should see',
    'assert'               => 'Then I should see',
    'waitFor'              => 'Then I should see',
);
?>
