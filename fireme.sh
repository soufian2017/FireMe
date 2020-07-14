#!/bin/bash


## RUNTIME STRAT
start=`date +%s`

red=`tput setaf 1`
redb=`tput setab 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
blue=`tput setaf 4`
lighblue=`tput setaf 6`
reset=`tput sgr0`



FOLDER='/data'
wordlist='/opt/SecLists/Discovery/Web-Content/directory-list-2.3-medium.txt'
date=$(date +'%d-%m-%Y')
THREADS=50

path=''
zip=''

## Pretty print

star="${lighblue}[*]${reset}"
hit="${yellow}[!]${reset}"
plus="${green}[+]${reset}"
minus="${red}[-]${reset}"


logo(){

	clear

	echo -e ""
	echo -e "${blue}   (                    *        "
	echo -e "  )\ )               (  \`        "
	echo -e "${red} (()/( (  (     (    )\))(    (  "
	echo -e "${yellow} /(_)))\ )(   ))\  ((_)()\  ))\  "
	echo -e "${lighblue}(_))_((_|()\ /((_) (_()((_)/((_) "
	echo -e "| |_  (_)((_|_))   |  \/  (_))   "
	echo -e "| __| | | '_/ -_)  | |\/| / -_)  "
	echo -e "|_|   |_|_| \___|  |_|  |_\___|  "
	echo -e "\n\n${reset}"

}

Usage(){
	echo -e "Usage: $0 [REQUIRED] [OPTIONS]\n"
	echo -e "[REQUIRED]"
	echo -e "\t-z ZIP \tZip file containing subdomains\n"
	echo -e "[OPTIONS]"
	echo -e "\t-h \tPrint this help message"
	exit
}

make_dirs(){

	path="$FOLDER/$1/$date"
	mkdir $path -p
	
	if [ -d $path/subdomains ]; then
		rm -r $path/subdomains
	else
		mkdir $path/subdomains -p
	fi
	
	mkdir $path/http -p
	mkdir $path/urls -p
	mkdir $path/wordlists -p
	mkdir $path/nmap -p
	mkdir $path/takeover -p
	mkdir $path/vulns -p
	mkdir $path/intresting -p
	mkdir $path/dns -p
	
}

make_files(){
	
	cp ./resolvers.txt $path/dns/resolvers.txt
	cp -u $(locate providers.json) . ## Needed for SubOver

}

handle_zip(){

	unzip $1 -d $path/subdomains > /dev/null

}

get_http(){

	cat $path/subdomains/* | sort -u > $path/subdomains/all.txt
	cat $path/subdomains/all.txt | httprobe -prefer-https -c $THREADS | sort -u > $path/http/alive.txt
	
	cat $path/http/alive.txt | sed 's/^https\?:\/\///g' | sort -u > $path/http/domains_alive.txt
	
	diff $path/subdomains/all.txt $path/http/domains_alive.txt | grep -E '^<' | sed 's/< //g' | sort -u > $path/http/dead.txt
	
	cat $path/http/alive.txt | sed 's/^https\?:\/\///g' | sort -u > $path/subdomains/alive.txt
	cp $path/http/dead.txt $path/subdomains/dead.txt

}

gen_urls(){
	
	cat $path/http/alive.txt | gau | sort -u > $path/urls/gau.txt
	cat $path/http/alive.txt | waybackurls -no-subs | sort -u > $path/urls/waybackurls.txt
	
	cat $path/urls/waybackurls.txt $path/urls/gau.txt | sort -u > $path/urls/all.txt 2> /dev/null
	
	cat $path/urls/all.txt | sort -u | grep -iP "\w+\.js(\?|$)" | sort -u > $path/urls/js_urls.txt
	echo -e "\t${plus} JS Urls ${reset}"
	cat $path/urls/all.txt | sort -u | grep -iP "\w+\.php(\?|$)" | sort -u > $path/urls/php_urls.txt
	echo -e "\t${plus} PHP Urls ${reset}"
	cat $path/urls/all.txt | sort -u | grep -iP "\w+\.aspx(\?|$)" | sort -u > $path/urls/aspx_urls.txt
	echo -e "\t${plus} Aspx Urls ${reset}"
	cat $path/urls/all.txt | sort -u | grep -iP "\w+\.jsp(\?|$)" | sort -u > $path/urls/jsp_urls.txt
	echo -e "\t${plus} JSP urls ${reset}"
	cat $path/urls/all.txt | sort -u | grep -iP "\w+\.zip(\?|$)" | sort -u > $path/urls/zip_urls.txt
	echo -e "\t${plus} ZIP urls ${reset}"
	cat $path/urls/all.txt | sort -u | grep -iP "\w+\.bak(\?|$)" | sort -u > $path/urls/bak_urls.txt
	cat $path/urls/all.txt | sort -u | grep -iP "\w+~(\?|$)" | sort -u >> $path/urls/bak_urls.txt
	echo -e "\t${plus} Backup urls ${reset}"

}

gen_wordlists(){

	cat $path/urls/all.txt | unfurl -u keys > $path/wordlists/keys.txt
	cat $path/urls/all.txt | unfurl -u paths > $path/wordlists/paths.txt
	
	cat $path/urls/{bak,aspx,jsp,php,zip}_urls.txt | sort -u > $path/wordlists/tmp.txt
	cat $path/urls/all.txt | gf http_junk | sort -u >> $path/wordlists/tmp.txt
	cat $path/wordlists/tmp.txt | sort -u > $path/wordlists/clean.txt

}

check_vulns(){

	cat $path/wordlists/clean.txt | gf ssrf > $path/vulns/ssrf.txt
	cat $path/wordlists/clean.txt | gf ssti > $path/vulns/ssti.txt
	cat $path/wordlists/clean.txt | gf idor > $path/vulns/idor.txt
	cat $path/wordlists/clean.txt | gf lfi > $path/vulns/lfi.txt
	cat $path/wordlists/clean.txt | gf rce > $path/vulns/rce.txt
	cat $path/wordlists/clean.txt | gf sqli > $path/vulns/sqli.txt
	cat $path/wordlists/clean.txt | gf upload-fields > $path/vulns/upload-fields.txt
	
	
	cat $path/wordlists/clean.txt | gf aws-keys > $path/intresting/aws-keys.txt
	cat $path/wordlists/clean.txt | gf debug_logic > $path/intresting/debug_logic.txt
	cat $path/wordlists/clean.txt | gf redirect > $path/intresting/redirect.txt

}

nmap_it(){
	
	for d in $(cat $path/subdomains/all.txt); do
		nmap -sV $d -p 80,443,8080,8443 --script http-title -T4 -oN $path/nmap/$d.txt --open > /dev/null
	done
	
	[[ -f $path/nmap/all.txt ]] && rm $path/nmap/all.txt
	cat $path/nmap/* > $path/nmap/all.txt
	
	cat $path/nmap/all.txt | grep -ivE '(host|other|#|closed|Not shown)' > $path/nmap/tmp.txt
	mv $path/nmap/tmp.txt $path/nmap/all.txt
	echo -e "${hit} Check nmap output : ${path}/nmap/all.txt ${reset}"

}

takeover(){

	echo -e "\t${plus} Lunching subjack ${reset}"
	subjack -w $path/subdomains/all.txt -t $THREADS -ssl -a -o $path/takeover/subjack.txt > /dev/null
	[[ -f $path/takeover/subjack.txt ]] && echo -e "\n${hit} Hit : ${blue}${path}/takeover/subjack.txt${reset} ${reset}" || echo -e "\t${minus} Nothing found ${reset}"
	
	echo -e "\t${plus} Lunching takeover.py ${reset}"
	takeover.py -l $path/subdomains/all.txt -t $THREADS -o $path/takeover/takeover.txt -T 5 > /dev/null
	[[ -f $path/takeover/takeover.txt ]] && [[ $(wc -l $path/takeover/takeover.txt | awk '{print $1}') -ne "2" ]] && echo -e "\t${hit} Hit : ${blue}${path}/takeover/takeover.txt${reset} ${reset}" || echo -e "\t${minus} Nothing found ${reset}"
	
	echo -e "\t${plus} Lunching SubOver ${reset}"
	SubOver -a -https -l $path/subdomains/all.txt -t $THREADS -o $path/takeover/SubOver.txt > /dev/null
	[[ -f $path/takeover/SubOver.txt ]] && echo -e "\t${hit} Hit : ${blue}${path}/takeover/SubOver.txt${reset} ${reset}\n" || echo -e "\t${minus} Nothing found ${reset}\n"

}

massdns_dump(){

	massdns -r $path/dns/resolvers.txt -w $path/dns/out.txt -c $THREADS -q $path/subdomains/all.txt
	gf ip $path/dns/out.txt | awk -F ':' '{print $3}' > $path/dns/all.txt
	diff $path/dns/all.txt $path/dns/resolvers.txt | grep -E '^<' | sed 's/< //g' | sort -u > $path/dns/ips.txt

}



clean(){

	rm $path/http/domains_alive.txt
	rm $path/subdomains/all.txt
	rm $path/wordlists/tmp.txt
	
	rm providers.json

}


## BEGIN HERE


while getopts ":z:h" opt; do
	case $opt in
		
	h) Usage ;;
		z) zip=$OPTARG ;;
	*) Usage ;;
	
	esac
done

[[ ! -z $zip ]] || Usage


## MAIN

main(){
	
	logo
	clean 2> /dev/null
	
	make_dirs $zip
	make_files
	handle_zip $zip
	
	echo -e "${blue}   [---] Starting Passive Enum [---]\n${reset}"
	echo -e "${star} Scanning for live domains${reset}"
	get_http
	
	echo -e "${star} Generating URLS${reset}"
	gen_urls
	
	echo -e "\n${star} Generating wordlists${reset}"
	gen_wordlists
	
	echo -e "${star} Dumping possible vulns${reset}"
	check_vulns
	
	echo -e "${star} Starting subdomains takeover${reset}"
	cat $path/subdomains/* | sort -u > $path/subdomains/all.txt
	takeover
	
	echo -e "${star} Dumping IP addresses${reset}"
	massdns_dump
	
	echo -e "${star} Starting nmap ${reset}\n"
	nmap_it
	
	
	echo -e "\n${blue}   [---] Starting Active Enum [---]\n${reset}"
	
	## TODO:
	#	- Gobuster
	#	- aquatone
	#	- get HTML
	#	- Get IP for masscan
	
	echo -e "\n${star} Cleaning up ${reset}\n"
	clean 2> /dev/null
	echo -e "\n\n${red}/${blue}\ ${green}*** ${yellow}END ${green}*** ${blue}/${red}\ "
}


main
end=`date +%s`

runtime=$((end-start))

echo "${reset}Scan completed in : $(($runtime / 60)) minutes and $(($runtime % 60)) seconds."
