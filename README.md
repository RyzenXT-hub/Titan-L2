# Bash Shell Auto Install Titan Node L2 - Cassini Testnet on Ubuntu 22.04+
- Install (version v0.1.19)
```
curl -O https://raw.githubusercontent.com/RyzenXT-hub/Titan-L2/main/install.sh && chmod u+x install.sh && ./install.sh
```
- Show Info & Config node
```
titan-edge config show && titan-edge info
```
- If errors, delete folder `.titanedge` and reinstall
```
systemctl stop titand.service && rm -rf /root/.titanedge && rm -rf /usr/local/titan
```
------------

- Contact Telegram : https://t.me/Ryzen_XT
- Reff Link : https://test1.titannet.io/intiveRegister?code=NDKWgo
