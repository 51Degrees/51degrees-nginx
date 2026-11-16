<?php

/**
 * Example requests against the Docker image that run.sh starts. Its
 * configuration, nginx.conf in this folder, loads the device detection module
 * and answers on /hash with the values in response headers.
 *
 * The match uses the User-Agent and Sec-CH-UA-* headers, so the requests
 * show what the module makes of the same browser with and without client
 * hints. The IP Intelligence examples are in examples/ipi and examples/mixed.
 */

const HOST = '127.0.0.1:8080';

/**
 * Make a HEAD request to the URL with the headers provided and print the
 * response headers.
 *
 * @param string $title printed before the response.
 * @param string $url the URL to request.
 * @param array $headers the request headers to set.
 */
function request(string $title, string $url, array $headers = [])
{
    echo "=== $title ===\n";

    $c = curl_init();
    curl_setopt($c, CURLOPT_URL, $url);
    curl_setopt($c, CURLOPT_HEADER, true);
    curl_setopt($c, CURLOPT_NOBODY, true);
    curl_setopt($c, CURLOPT_RETURNTRANSFER, true);
    if (count($headers) > 0) {
        curl_setopt($c, CURLOPT_HTTPHEADER, $headers);
    }

    $response = curl_exec($c);
    if ($response === false) {
        echo 'Request failed: ' . curl_error($c) . "\n";
    } else {
        echo $response;
    }

    curl_close($c);
}

request(
    'Desktop browser with client hints',
    'http://' . HOST . '/hash',
    [
        'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.41',
        'Sec-CH-UA: "Not.A/Brand";v="8","Chromium";v="114","Microsoft Edge";v="114"',
        'Sec-CH-UA-Arch: x86',
        'Sec-CH-UA-Bitness: 64',
        'Sec-CH-UA-Full-Version: 114.0.5735.110',
        'Sec-CH-UA-Full-Version-List: "Not.A/Brand";v="8.0.0.0","Chromium";v="114.0.5735.110","Microsoft Edge";v="114.0.1823.41"',
        'Sec-CH-UA-Mobile: ?0',
        'Sec-CH-UA-Model: ',
        'Sec-CH-UA-Platform: Windows',
        'Sec-CH-UA-Platform-Version: 15.0.0',
    ]
);

request(
    'Mobile browser',
    'http://' . HOST . '/hash',
    [
        'User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 7_1 like Mac OS X) AppleWebKit/537.51.2 (KHTML, like Gecko) Version/7.0 Mobile/11D167 Safari/9537.53',
    ]
);
