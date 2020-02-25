function checkAllBalances() {
    var totalBal = 0;
    for (var acctNum in eth.accounts) {
        var acct = eth.accounts[acctNum];
        var acctBal = web3.fromWei(eth.getBalance(acct), "ether");
        totalBal += parseFloat(acctBal);
        console.log("  eth.accounts[" + acctNum + "]: \t" + acct + " \tbalance: " + acctBal + " NRG");
    }
    console.log("  Total balance: " + totalBal + " NRG");
    return true;
};

function checkBalance(acct) {
    var acctBal = web3.fromWei(eth.getBalance(acct), "ether");
    console.log(" account:\t" + acct + " \tbalance: " + acctBal + " NRG");
    return true;
};

function mnBalances() {
    var totalBal = 0;
    for (var acctNum in eth.accounts) {
        var acct = eth.accounts[acctNum];
        var acctBal = web3.fromWei(masternode.masternodeInfo(acct).collateral, "ether");
        totalBal += parseFloat(acctBal);
        console.log("  mn.accounts[" + acctNum + "]: \t" + acct + " \tbalance: " + acctBal + " NRG");
    }
    console.log("  Total balance: " + totalBal + " NRG");
    return true;
};
