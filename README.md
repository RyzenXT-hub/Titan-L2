# Bash Shell Auto Install Titan Node L2 - Cassini Testnet on Ubuntu 22.04+
- Install (version 0.1.19+git.89e53b6+api1.0.0) Bug Fixed Patch  29.06.24 
```
curl -O https://raw.githubusercontent.com/RyzenXT-hub/Titan-L2/main/install.sh && chmod u+x install.sh && ./install.sh
```
- If you previously used this auto script, please update your L2 with this
```
wget https://raw.githubusercontent.com/RyzenXT-hub/Titan-L2/main/update_titan.sh && chmod +x update_titan.sh && ./update_titan.sh
```
- Show Info & Config node
```
titan-edge config show && titan-edge info
```
- If errors, delete folder `.titanedge` and reinstall
```
systemctl stop titand.service && rm -rf /root/.titanedge && rm -rf /usr/local/titan
```



- Contact Telegram : https://t.me/Ryzen_XT
- Reff Link : https://test1.titannet.io/intiveRegister?code=NDKWgo
