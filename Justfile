up:
    ./linux-desktop up

down:
    ./linux-desktop down

restart:
    ./linux-desktop restart

status:
    ./linux-desktop status

shell:
    ./linux-desktop shell

build:
    ./linux-desktop build

clean:
    ./linux-desktop clean

reset:
    ./linux-desktop reset

doctor:
    ./linux-desktop doctor

# deprecated aliases, kept for backward compatibility
run: up
stop: down

lint:
    shellcheck linux-desktop scripts/*
