#!/bin/bash

# Clean up first
docker-compose down -v
docker system prune -a --volumes -f

# Create necessary directories
mkdir -p docker/{nginx/conf.d,php,data/{mysql,redis}}

# Set proper permissions
chmod -R 777 docker/data/{mysql,redis}

# Create initial nginx config if it doesn't exist
if [ ! -f docker/nginx/conf.d/app.conf ]; then
    cp docker/nginx/conf.d/app.conf.example docker/nginx/conf.d/app.conf 2>/dev/null || :
fi

# Build and start containers
docker-compose up -d --build

# Function to check MySQL connection
check_mysql_connection() {
    docker-compose exec -T mysql mysqladmin ping -h localhost -u root -p"${DB_PASSWORD:-your_password}" --silent
    return $?
}

# Function to initialize database
initialize_database() {
    echo "Initializing database..."
    docker-compose exec -T mysql mysql -u root -p"${DB_PASSWORD:-your_password}" -e "
        CREATE DATABASE IF NOT EXISTS laravel_db;
        CREATE USER IF NOT EXISTS 'laravel_user'@'%' IDENTIFIED BY 'your_password';
        GRANT ALL PRIVILEGES ON laravel_db.* TO 'laravel_user'@'%';
        FLUSH PRIVILEGES;
    "
}

# Wait for MySQL with timeout
echo "Waiting for MySQL to be ready..."
TIMEOUT=120
ELAPSED=0
until check_mysql_connection || [ $ELAPSED -gt $TIMEOUT ]; do
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    echo "Still waiting for MySQL... ($ELAPSED seconds)"
done

if [ $ELAPSED -gt $TIMEOUT ]; then
    echo "Error: MySQL connection timeout"
    exit 1
fi

echo "MySQL is ready!"
initialize_database

# Configure Laravel environment
docker-compose exec -T app bash -c 'cat > .env << EOL
APP_NAME=Laravel
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_URL=http://localhost:8000

LOG_CHANNEL=stack
LOG_LEVEL=debug

DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=laravel_db
DB_USERNAME=laravel_user
DB_PASSWORD=your_password

REDIS_CLIENT=predis
REDIS_HOST=redis
REDIS_PASSWORD=null
REDIS_PORT=6379

CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis
EOL'

# Generate app key and clear config
docker-compose exec -T app php artisan key:generate
docker-compose exec -T app php artisan config:clear

# Verify database connection
echo "Verifying database connection..."
if ! docker-compose exec -T app php artisan db:show; then
    echo "Database connection failed. Check your credentials and try again."
    exit 1
fi

# Install dependencies and setup Laravel
docker-compose exec -T app composer install
docker-compose exec -T app composer require predis/predis

# Create cache tables first
echo "Creating cache tables..."
docker-compose exec -T app php artisan config:cache
docker-compose exec -T app php artisan cache:table
docker-compose exec -T app php artisan session:table
docker-compose exec -T app php artisan queue:table
docker-compose exec -T app php artisan migrate --force

# Clear all caches with file driver
docker-compose exec -T app bash -c '
sed -i "s/CACHE_DRIVER=.*/CACHE_DRIVER=file/" .env
sed -i "s/SESSION_DRIVER=.*/SESSION_DRIVER=file/" .env
php artisan config:clear
php artisan cache:clear
php artisan view:clear

# Switch back to Redis
sed -i "s/CACHE_DRIVER=.*/CACHE_DRIVER=redis/" .env
sed -i "s/SESSION_DRIVER=.*/SESSION_DRIVER=redis/" .env
'

# Run remaining migrations
docker-compose exec -T app php artisan migrate --force

# Setup frontend
docker-compose exec -T app npm install
docker-compose exec -T app npm install -D tailwindcss postcss autoprefixer
docker-compose exec -T app npx tailwindcss init -p
docker-compose exec -T app npm run build

echo "Setup completed successfully!"
