# Customizing your reMarkable Paper Pro

Once you've set your **reMarkable Paper Pro** in **Developer Mode** and connected to it via an Ethernet-capable USB cable, this repo shows how to:

1. enable Wi-Fi SSH
2. install Tailscale static binaries in userspace mode
3. expose the tablet SSH daemon through Tailscale
4. install a local `ssh rem` alias on macOS

## Motivation

The Paper Pro can do USB SSH out of the box in Developer Mode, and can do Wi-Fi SSH after:

```sh
rm-ssh-over-wlan on
```

But plain Tailscale-on-Linux docs are not enough on this device because:

- the root filesystem is read-only by default
- `/dev/net/tun` is missing
- plain `ssh root@100.x.y.z` over Tailscale does **not** work here

So the working setup is:

- `tailscaled --tun=userspace-networking`
- `tailscale serve` on port `2222`
- a small systemd timer that keeps the `serve` backend pointed at the tablet's current `wlan0` IP
- local SSH config that uses `tailscale nc`

## Requirements

Mac:

- `sshpass`
- `tailscale`
- `uv`

Tablet:

- reMarkable Paper Pro
- Developer Mode enabled
- the random root password from:
  `Settings -> Help -> Copyrights and licenses -> General Information`

## Env

Copy:

```sh
cp .env.example .env
```

Then fill:

```sh
SSH_PWD=your-device-password
RM_WIFI_HOST=your-current-tablet-wifi-ip
```

## Steps

### 1. Enable Wi-Fi SSH over USB

Connect to your tablet via USB, then:

```sh
./scripts/enable-wifi-ssh.sh
```

What it runs on the tablet:

```sh
rm-ssh-over-wlan on
```

### 2. Install Tailscale on the tablet

```sh
./scripts/install-tailscale.sh
```

This installs the official static `arm64` binaries under:

```sh
/home/root/tailscale
```

and writes:

```sh
/etc/systemd/system/tailscaled-remarkable.service
```

The service runs:

```sh
tailscaled --tun=userspace-networking
```

### 3. Join the tablet to your tailnet

```sh
./scripts/tailscale-up.sh
```

The script prints a Tailscale auth URL. Open it, approve the device, then continue.

### 4. Install the SSH bridge

```sh
./scripts/install-tailscale-ssh-bridge.sh
```

This installs:

- `/home/root/tailscale/update-serve-ssh.sh`
- `tailscale-serve-ssh.service`
- `tailscale-serve-ssh.timer`

What it does:

- reads the current `wlan0` IPv4
- runs:

```sh
tailscale serve --bg --yes --tcp 2222 -- tcp://<wlan0-ip>:22
```

- refreshes every 30s so Wi-Fi IP changes heal automatically

### 5. Install local SSH alias

```sh
./scripts/install-ssh-config.sh
```

If the tablet is not directly reachable on its Wi-Fi IP but you already have a working SSH alias/path, pass that instead:

```sh
./scripts/install-ssh-config.sh rem
```

This writes a host like:

```sshconfig
Host rem
    HostName <tablet-tailnet-dns-name>
    User root
    HostKeyAlias remarkable-paper-pro
    ProxyCommand tailscale nc %h 2222
    StrictHostKeyChecking accept-new
```

Then use:

```sh
ssh rem
```

## Re-test

Quick checks:

```sh
ssh rem
tailscale status
```

From the tablet side:

```sh
systemctl status tailscaled-remarkable.service
systemctl status tailscale-serve-ssh.timer
/home/root/tailscale/bin/tailscale --socket=/run/tailscale/tailscaled.sock serve status
```

## Notes

- Your Mac does **not** need to be on the same Wi-Fi.
- The tablet does still need internet access.
- Plain `ssh root@100.x.y.z` is expected to fail on this setup.
- `ssh rem` works because SSH is tunneled through:

```sh
tailscale nc <tablet-tailnet-dns-name> 2222
```

## Recover / rerun

If the tablet Wi-Fi IP changed and the bridge looks stale:

```sh
ssh rem 'systemctl start tailscale-serve-ssh.service'
```

If Tailscale needs re-auth:

```sh
./scripts/tailscale-up.sh
```

If you want to rewrite local SSH config:

```sh
./scripts/install-ssh-config.sh rem
```

## References

- [reMarkable Developer Mode](https://developer.remarkable.com/documentation/developer-mode)
- [reMarkable SDK docs](https://developer.remarkable.com/documentation/sdk)
- [Tailscale Linux install](https://tailscale.com/docs/install/linux)
- [Tailscale userspace networking](https://tailscale.com/docs/concepts/userspace-networking)
- [Tailscale serve CLI](https://tailscale.com/docs/reference/tailscale-cli/serve)
