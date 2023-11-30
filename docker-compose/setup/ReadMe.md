# Setup

This directory is bind-mounted into container when the script `setup.sh` from
the root directory is executed and is used to set up the core container for
staking.

Before running `setup.sh` the keystore file must be placed in the directory
`.energi_core/keystore`.

> It is advisable to keep a copy of the keystore file somewhere else as it will
> be moved from the directory `.energi_core/keystore` to the Energi Core Node
> data directory volume.
