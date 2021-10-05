<?php

    $jwk = [
        'kty' => 'RSA',
        'n'   => 'qE0KH1Os4O941MUZc6Pam9qdtEoF7Xgy5O1z5QVSAxObd1KtTvrNSS2U50NMn1_Zi5kwnWS1Ov9q71PygmyKA3h1UcLWukGe8zWtGlDxPwACZIZixYP3AHiMDUSSHqQSwRtYLUFr5Wye0SEDbPd22KPVAkoX4YxOeyE5uDTGPRCKWC_DdCjt7INzXWvP_kUeFy541aiSd0bZ82PH2WNY73krUFZM2NHHqXiN0VdhzVDeI9MoVX8Pm8lk5SotXWxH7Y6iVqllG98X83X_OKMAyajsgN8t2oe12OZFMf18MUHO1EBq9ZJzZQTLEDgI5Egr8Pcx46RWH_3FlScCEFoFYw',
        'e'   => 'AQAB',
    ];
    $keyAsJson = json_encode($jwk);
    //echo $keyAsJson;
    //echo "\n";
    $h = hash('sha256', $keyAsJson, true);
    $base64Url = strtr(base64_encode($h), '+/', '-_');
    $digest = rtrim($base64Url, '=');
    echo $base64Url;
?>