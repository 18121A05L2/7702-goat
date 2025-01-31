FROM mcr.microsoft.com/vscode/devcontainers/base:debian
RUN apt-get update
ENV SHELL=/usr/bin/zsh
SHELL ["/usr/bin/zsh", "-c"]
USER vscode
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && source $HOME/.cargo/env
RUN curl -L https://foundry.paradigm.xyz | zsh
RUN foundryup
RUN sudo apt-get autoremove -y && sudo apt-get clean -y
