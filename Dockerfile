# Using official minimal base image for security purposes
FROM --platform=linux/amd64 debian:bullseye-slim AS builder

# Setting environment vars for Bitcoin Core versions & URL
ENV BITCOIN_VERSION=27.1
ENV BITCOIN_URL=https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/
ENV SHA256SUMS_URL=${BITCOIN_URL}SHA256SUMS
ENV SHA256SUMS_ASC_URL=${BITCOIN_URL}SHA256SUMS.asc

# Installing necessary dependencies for downloading & verifying Bitcoin Core checksums
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Importing all GPG keys from the devs who had signed the release
RUN gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys \
    01EA5486DE18A882D4C2684590C8019E36C2E964 \
    CFB16E21C950F67FA95E558F2EEB9F5CC09526C1 \
    152812300785C96444D3334D17565732E08E5E41 \
    C388F6961FB972A95678E327F62711DBDCA8AE56 \
    9DEAE0DC7063249FB05474681E4AED62986CD25D \
    D1DBF2C4B96F2DEBF4C16654410108112E7EA81F \
    F2CFC4ABD0B99D837EEBB7D09B79B45691DB4173 \
    637DB1E23370F84AFF88CCE03152347D07DA627C \
    F4FC70F07310028424EFC20A8E4256593F177720 \
    1A3E761F19D2CC7785C5502EA291A2C45D0C504A \
    E86AE73439625BBEE306AAE6B66D427F873CB1A3 \
    670BC460DC8BF5EEF1C3BC74B14CC9F833238F85 \
    F19F5FF2B0589EC341220045BA03F4DBE0C63FB4 \
    ED9BDF7AD6A55E232E84524257FF9BDBCC301009

# Downloading Bitcoin Core & verifying its checksum & signature
WORKDIR /tmp
RUN curl -O ${BITCOIN_URL}bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz \
    && curl -O ${SHA256SUMS_URL} \
    && curl -O ${SHA256SUMS_ASC_URL} \
    && gpg --verify SHA256SUMS.asc \
    && grep "bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz" SHA256SUMS | sha256sum -c - \
    && tar -xzvf bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz

# Setting up the final environment
FROM debian:bullseye-slim

# Installing runtime dependencies
RUN apt-get update && apt-get install -y \
    libevent-2.1-7 \
    libboost-system1.74.0 \
    libboost-filesystem1.74.0 \
    libboost-thread1.74.0 \
    libminiupnpc17 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Creating non-root user & setting permissions
RUN useradd -m -d /home/bitcoin -s /bin/bash bitcoin \
    && mkdir /home/bitcoin/.bitcoin \
    && chown -R bitcoin:bitcoin /home/bitcoin

# Copying binaries from builder stages
COPY --from=builder /tmp/bitcoin-27.1/bin /usr/local/bin/

# Setting permissions for Bitcoin binaries
RUN chmod +x /usr/local/bin/bitcoind /usr/local/bin/bitcoin-cli

# Setting bitcoin user & its home directory
USER bitcoin
WORKDIR /home/bitcoin

# Exposing required ports
EXPOSE 8332 8333

# Setting default commands to run the daemon
CMD ["bitcoind", "-printtoconsole"]

