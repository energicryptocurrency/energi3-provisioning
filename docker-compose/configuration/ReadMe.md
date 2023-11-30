# Configuration files for `docker-compose`

The following files containing Energi Gen 3 account access data must be added to
this directory before executing the command `docker-compose up --detach`:

- `energi3_account_address` - contains address(es); multiple addresses must be
  separated with comma;
- `energi3_account_password` - contains password(s); in case of multiple
  passwords they must be each on its own line in the same order as addresses.

These files will be added to container and used to automatically unlock account
for staking.
