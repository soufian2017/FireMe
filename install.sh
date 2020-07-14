go get -u github.com/tomnomnom/httprobe
go get github.com/tomnomnom/waybackurls
GO111MODULE=on go get -u -v github.com/lc/gau
go get -u github.com/tomnomnom/unfurl
go get -u github.com/tomnomnom/gf
go get github.com/haccer/subjack
git clone https://github.com/m4ll0k/takeover.git
cd takeover
sudo python3 setup.py install
cd ..
rm -fr takeover
go get github.com/Ice3man543/SubOver
git clone https://github.com/blechschmidt/massdns.git
cd massdns
make
cp bin/massdns /usr/local/bin/
cd ..
rm -fr massdns

