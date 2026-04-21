# List all available commands
list:
    @just --list

# Start the development server
dev:
    pnpm dev

# Install packages
i:
    pnpm i

# Update packages to their latest versions
up:
    pnpm up --latest

# List all packages
ls:
    pnpm ls

# Check outdated packages
outdated:
    pnpm outdated

# biome check --write
biome:
    pnpm biome check --write