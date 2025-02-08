<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ config('app.name', 'Laravel') }}</title>

    <!-- Fonts -->
    <link rel="preconnect" href="https://fonts.bunny.net">
    <link href="https://fonts.bunny.net/css?family=figtree:400,500,600&display=swap" rel="stylesheet" />

    <!-- Vite Assets -->
    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>

<body class="font-sans antialiased bg-white">
    <h1 class="text-center mt-20 text-green-500 text-3xl">Welcome Minhajul Islam to {{ config('app.name') }}</h1>
    <p class="text-gray-700 text-center">Your application is now up and running!</p>
    <footer class="mt-4 text-center">
        <p>&copy; {{ date('Y') }} {{ config('app.name') }}. All rights reserved.</p>
    </footer>
</body>

</html>
