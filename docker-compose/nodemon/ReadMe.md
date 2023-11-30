# Energi Core Node Monitor for `energi-docker-compose`

Dockerised Energi Core Node Monitor for the dockerised Energi Core Node.

---

- [Enable the Energi Core Node Monitor service](#enable-the-energi-core-node-monitor-service)
  - [Environment variables](#environment-variables)
    - [Boolean-like values](#boolean-like-values)
    - [Environment variables explained](#environment-variables-explained)
      - [`DISCORD_WEBHOOK_CHANGE`](#discord_webhook_change)
      - [Discord webhook addresses](#discord-webhook-addresses)
        - [`DISCORD_WEBHOOK_ERROR`](#discord_webhook_error)
        - [`DISCORD_WEBHOOK_INFORMATION`](#discord_webhook_information)
        - [`DISCORD_WEBHOOK_SUCCESS`](#discord_webhook_success)
        - [`DISCORD_WEBHOOK_WARNING`](#discord_webhook_warning)
      - [`ECNM_CURRENCY`](#ecnm_currency)
      - [`ECNM_INTERVAL`](#ecnm_interval)
      - [`ECNM_SERVER_ALIAS`](#ecnm_server_alias)
      - [`ECNM_SHOW_IP`](#ecnm_show_ip)
      - [`ECNM_SHOW_IP_EXTERNAL`](#ecnm_show_ip_external)
      - [`INTERACTIVE_SETUP`](#interactive_setup)
      - [`MARKET_PRICE_IN_INFORMATION`](#market_price_in_information)
      - [`MESSAGE_TIME_ZONE`](#message_time_zone)
      - [`NRG_AMOUNT_IN_CURRENCY`](#nrg_amount_in_currency)
      - [`TELEGRAM_BOT_TOKEN`](#telegram_bot_token)
      - [`TELEGRAM_BOT_TOKEN_CHANGE`](#telegram_bot_token_change)

---

## Enable the Energi Core Node Monitor service

To enable Energi Core Node Monitor,
[`compose.override.template.yaml`](../compose.override.template.yaml)
has to be copied in the root directory and renamed to `compose.override.yaml`.
Then [`nodemon/.env.template.env`](.env.template.env) must be copied and renamed
to `.env` and values should be provided for environment variables when a
non-interactive setup is used (value for
[`INTERACTIVE_SETUP`](#interactive_setup) is a negative
[boolean-like value](#boolean-like-values)). All the environment variables are
described in [the subsection below](#environment-variables).

To setup Energi Core Node Monitor container, command `./helper setup monitor`
(or `./helper setup` if Energi Core Node and Energi Core Node Monitor are set up
together) must be executed from the root directory (where
[`compose.yaml`](../compose.yaml) is located). Energi Core Node
Monitor container will be automatically started afterwards.

> `docker compose` is used in `./helper setup` so `sudo` might be necessary.
>
> After the Energi Core Node Monitor container is launched for the first time or
> it is recreated, a message about user and group changes will be sent.
>
> A note on uptime value in informational messages. As originally
> [`nodemon.sh`](scripts/nodemon.sh) is intended to run on the same server as
> Energi Core Node, then uptime value is meant to be the uptime of Core. In
> `energi-docker-compose` this value is the uptime of the cron process in the
> Energi Core Node Monitor container as Core and Monitor run in separate Docker
> containers.

### Environment variables

`.env` contains environment variables that are used to set up Energi Core Node
Monitor in a non-interactive mode ([`INTERACTIVE_SETUP`](#interactive_setup) has
a positive [boolean-like](#boolean-like-values) value). All of them are optional
and most of them are used only in the configuration run.

#### Boolean-like values

The following values are considered as positive boolean values (`true`, case
insensitive):

- `y`;
- `yes`;
- `true`;
- `1`.

Anything else (including empty value or omitted variable) is considered as
`false`.

#### Environment variables explained

This section contains a short description for each of environment variables that
are used to configure the dockerised Energi Core Node Monitor.

##### `DISCORD_WEBHOOK_CHANGE`

For non-interactive setup a positive [boolean-like](#boolean-like-values) value
indicates that the existing Discord webhooks should be replaced with the value
of the following environment variables if the Energi Core Node Monitor has
already been set up:

- [`DISCORD_WEBHOOK_ERROR`](#discord_webhook_error);
- [`DISCORD_WEBHOOK_INFORMATION`](#discord_webhook_information);
- [`DISCORD_WEBHOOK_SUCCESS`](#discord_webhook_success);
- [`DISCORD_WEBHOOK_WARNING`](#discord_webhook_warning).

##### Discord webhook addresses

One webhook address can be used for all message types.

More detailed instructions on how to set up Discord to receive messages from the
Energi Core Node Monitor are located in
[the official Energi Core Node Monitoring Tool guide (the section "Setup Discord")](https://wiki.energi.world/en/advanced/nodemon#discord).

###### `DISCORD_WEBHOOK_ERROR`

Discord webhook address for error messages.

###### `DISCORD_WEBHOOK_INFORMATION`

Discord webhook address for information messages.

###### `DISCORD_WEBHOOK_SUCCESS`

Discord webhook address for success messages.

###### `DISCORD_WEBHOOK_WARNING`

Discord webhook address for warning messages.

##### `ECNM_CURRENCY`

The currency to be used in messages about wallet balance.

If not set, `USD` will be used.

##### `ECNM_INTERVAL`

An interval between two subsequent Energi Core Node Monitor runs. \
The following suffixes can be used to specify the desired time units:

- `s` or no suffix for seconds;
- `m` for minutes;
- `h` for hours;
- `d` for days.

When this environment variable is not defined or it's value is not specified,
the default interval will be used: 10 minutes.

##### `ECNM_SERVER_ALIAS`

A server name to be used in messages.

The default value: container's hostname (something like `35199a65247e`).

##### `ECNM_SHOW_IP`

A positive [boolean-like](#boolean-like-values) value indicates that the Energi
Core Node Monitor's IP address should be displayed in messages.

This value alone is quite pointless as it will display the Energi Core Node
Monitor Docker container's internal IP address.

To display server's external IP address, the environment variable
[`ECNM_SHOW_IP_EXTERNAL`](#ecnm_show_ip_external) must be set to a positive
[boolean-like](#boolean-like-values) value.

##### `ECNM_SHOW_IP_EXTERNAL`

When [`ECNM_SHOW_IP`](#ecnm_show_ip), a positive
[boolean-like](#boolean-like-values) value indicates that the server's external
IP address should be displayed in messages instead of container's internal IP.

##### `INTERACTIVE_SETUP`

A positive [boolean-like](#boolean-like-values) value indicates that the Energi
Core Node Monitor setup process will be interactive. This means that all the
neccessary values in setup process will have to be entered manually.

For interactive setup all environment variables can be left without values.

The default value is `yes`.

##### `MARKET_PRICE_IN_INFORMATION`

When set to a positive [boolean-like](#boolean-like-values) value, the current
market price will be added to informational message.

The default value is `no`.

##### `MESSAGE_TIME_ZONE`

To display date in time in messages in the specified time zone.

If `MESSAGE_TIME_ZONE` is omitted or its value is empty, or if time zone name
is misspelled, container's default time zone (UTC) will be used.

Available time zones are listed on:

- <https://twiki.org/cgi-bin/xtra/tzdatepick.html>;
- <https://en.wikipedia.org/wiki/List_of_tz_database_time_zones>.

##### `NRG_AMOUNT_IN_CURRENCY`

When set to a positive [boolean-like](#boolean-like-values) value, NRG balance
in success messages is displayed in the configured currency.

The default value is `no`.

##### `TELEGRAM_BOT_TOKEN`

Token for Telegram bot to send Energi Core Node Monitor messages to.

> When a Telegram bot is used, at least one message has to be sent to it
> recently so the `result` array in the response of
> `https://api.telegram.org/bot{Telegram bot token}/getUpdates` (where
> `{Telegram bot token}` is the actual token) is not empty, otherwise the script
> will not be able to set up Telegram integration.

Detailed instructions on how to set up Telegram are in
[the official Energi Core Node Monitoring Tool guide (the section "Setup Telegram")](https://wiki.energi.world/en/advanced/nodemon#telegram).

##### `TELEGRAM_BOT_TOKEN_CHANGE`

For interactive setup a positive [boolean-like](#boolean-like-values) value
indicates that the existing Telegram token must be replaced with the one that is
assigned to [`TELEGRAM_BOT_TOKEN`](#telegram_bot_token) if the Energi Core Node
Monitor has been already set up.
