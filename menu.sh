#!/bin/bash
#---------------------------------------------------------------------------------------
#
# Script         :                    menu.sh
# Description    :                    Simple bash convenience menu.
# version        :                    0.1
# Initial Authors:                    CODE_ERROR
# Initial Date   :                    2021.07.01
# Initial Source :                    -
#---------------------------------------------------------------------------------------
#
# Please make sure the user variables sections is correct
#
#---------------------------------------------------------------------------------------
# Start user varables
#---------------------------------------------------------------------------------------
# Internal cypher RPC port
RPC_PORT=8000
# External cypher ports
RNET_PORT=7100
P2P_PORT=6000

#---------------------------------------------------------------------------------------
# End user varables
#---------------------------------------------------------------------------------------

# Port Array
UDPportArray=(${RNET_PORT} ${P2P_PORT})
TCPportArray=(${P2P_PORT})

# Required packages
packageArray=(openssl libssl-dev curl libgmp-dev jq netcat nmap)

# Set bash Colours
CBlack='\033[0;30m'
CGreen='\033[0;32m'
CPurple='\033[0;35m'
CRed='\033[0;31m'
CLightBlue='\033[1;34m'
CYellow='\033[1;33m'
CWhite='\033[1;37m'
CLightCyan='\033[1;36m'
BCRed='\033[41m'
BCWhite='\033[47m'
BCGreen='\033[42m'
NOCOL='\033[0m' #No Colour

# Script name
ME=`basename ${0} .sh`

# Restricted (non root)
restricted=0

# Alias echo
E='echo -e'
e='echo -en'

# Catch sigint (CTRL-C)
trap "FULLRESET_TERMINAL;exit" SIGINT

ESC=$($e "\e")

# Init
i=0
LM=8

###############################################
#                  FUNCTIONS                  #
###############################################
MSG() {
    if [[ $# -gt 0 ]]
    then
        _DATE=` date '+%d.%m.%Y %H:%M:%S' `
        _ECHO="echo"
        _MESSAGE_TYPE=$1; shift;
        _MESSAGE="$*";
        if [[ "x$_MESSAGE_TYPE" = "xSTART" ]] || [[ "x$_MESSAGE_TYPE" = "xSTOP" ]]
        then
            if [[ "x$_MESSAGE_TYPE" = "xSTART" ]]; then printf "\n"; fi
            echo "####################################################################################################"
            echo "#                                  "$_MESSAGE_TYPE" on "$_DATE
            echo "####################################################################################################"
            if [[ "x$_MESSAGE_TYPE" = "xSTOP" ]]; then printf "\n"; fi
        else
            if [[ "x$_MESSAGE_TYPE" = "xFAILED" ]]; then _MESSAGE_TYPE="${CLightCyan}${BCRed}FAILED.${NOCOL}"; fi
            if [[ "x$_MESSAGE_TYPE" = "xPASSED"    ]]; then _MESSAGE_TYPE="${CPurple}${BCGreen}PASSED.${NOCOL}"; fi
            if [[ "x$_MESSAGE_TYPE" = "xWARNING"    ]]; then _MESSAGE_TYPE="${CLightCyan}${BCRed}WARNING${NOCOL}"; fi
            if [[ "x$_MESSAGE_TYPE" = "xINFO"   ]]; then _MESSAGE_TYPE="${CPurple}${BCGreen}INFO...${NOCOL}"; fi
            if [[ "x$_MESSAGE_TYPE" = "xYES"   ]]; then _MESSAGE_TYPE="${CPurple}${BCGreen}YES....${NOCOL}"; fi
            if [[ "x$_MESSAGE_TYPE" = "xNO"   ]]; then _MESSAGE_TYPE="${CLightCyan}${BCRed}NO.....${NOCOL}"; fi
            if [[ -n "$_MESSAGE" ]]; then _ECHO="$_ECHO -e $_DATE - $_MESSAGE_TYPE - $_MESSAGE "; fi
            if [[ "x$_ECHO" != "xecho" ]]; then $_ECHO; fi
        fi
    else
        echo "MSG() function error"
    fi
}

IS_CYPHER_RUNNING() {
    pid=$(pgrep cypher) 2>/dev/null && {
        echo "${pid}"
        return 0
    }
    return 1
}

DECIMAL_TO_HEXADECIMAL() {
    # Requires decimal number as argument 1
    echo $(printf "0x%x\n" $((10#${1})))
}

HEXADECIMAL_TO_DECIMAL() {
    # Requires hexadecimal number as argument 1
    echo $(printf "%d\n" $((${1})))
}

GET_EXTERNAL_IP() {
    echo $(dig +short myip.opendns.com @resolver4.opendns.com)
}

IS_UDP_PORT_OPEN() {
    report=$(nmap -sU -p "$2" "$1" --open -oG - | sed -n 's/^\(.*Host.*\)|.*/\1/p') && {
        echo "${report}"
        return 0
    }
    return 1
}

IS_TCP_PORT_OPEN() {
    report=$(nmap -p "$2" "$1" --open -oG - | sed -n 's/^\(.*Host.*\)\/tcp.*/\1/p') && {
        echo "${report}"
        return 0
    }
    return 1
}

IS_LOCAL_TCP_PORT_OPEN() {
    # Requires local port number as argument 1
    nc -zvw10 0.0.0.0 "${1}" 2>/dev/null
    return $?
}

PROGRAM_EXISTS() {
    if ! program_location="$(type -p "${1}")" || [[ -z ${program_location} ]]; then return 1; fi
    return 0
}

PACKAGE_AVAILABLE() {
    packageResult="$(apt-cache policy "${1}")"
    if [[ -z ${packageResult} ]]; then return 1; fi
    return 0
}

PACKAGE_INSTALLED() {
    if [[ $(apt-cache policy "${1}") =~ "Installed: (none)" ]]; then return 1; fi
    return 0
}

GET_BALANCE() {
    # Requires coinbase as argument 1
    echo $(curl --silent -X POST -H "Content-Type: application/json" --data '{"method": "cph_getBalance", "params": ["'${1}'", "latest"], "id":"1"}' 0.0.0.0:8000 | jq -r '.result')
}

DIVIDE_BY_QUINTILLION() {
    # Requires balance (integer) as argument 1
    # Requires scale (integer) as argument 2
    echo $(bc -l <<< "scale=${2}; ${1}/1000000000000000000")
}

GET_DECIMAL_KEY_BLOCK() {
    echo $(curl --silent -X POST -H "Content-Type: application/json" --data '{"id":"1", "method": "cph_keyBlockNumber"}' 0.0.0.0:${RPC_PORT} | jq -r '.result')
}

GET_COMMITTEE_MEMBERS() {
    # Requires hexadecimal keyblock number as argument 1
    echo $(curl -X POST --silent -H "Content-Type: application/json" --data '{"id":"1", "method": "cph_committeeMembers", "params": ["'${1}'"]}' 0.0.0.0:${RPC_PORT} | jq -r '.result')
}

GET_COINBASE() {
    echo $(curl --silent -X POST -H "Content-Type: application/json" --data '{"id":"1", "method": "cph_coinbase"}' 0.0.0.0:${RPC_PORT} | jq -r '.result')
}

GET_MINER_STATUS() {
    echo $(curl --silent -X POST -H "Content-Type: application/json" --data '{"id":"1", "method": "miner_status"}' 0.0.0.0:${RPC_PORT} | jq -r '.result')
}

IS_MINER_RUNNING() {
    if [[ $(IS_CYPHER_RUNNING) && $(GET_MINER_STATUS | grep -E "Running") ]]; then return 0; fi
    return 1
}

IS_COINBASE_IN_COMMITTEE() {
    # Requires hexadecimal keyblock number as argument 1
    # Requires coinbase as argument 2
    committee=$(curl --silent -X POST -H "Content-Type: application/json" --data '{"id":"1", "method": "cph_committeeMembers", "params": ["'${1}'"]}' 0.0.0.0:${RPC_PORT} | jq -e '.result[] | select(.coinbase | test("(?i)'${2}'"))') && {
        return 0
    }
    return 1
}

IS_COINBASE_IN_COMMITTEE_EXCEPTION() {
    # Requires hexadecimal keyblock number as argument 1
    # Requires coinbase as argument 2
    committeeException=$(curl --silent -X POST -H "Content-Type: application/json" --data '{"id":"1", "method": "cph_committeeExceptions", "params": ["'${1}'"]}' 0.0.0.0:${RPC_PORT} | jq -e 'select(.result[] | test("(?i)'${2}'"))') && {
        return 0
    }
    return 1
}

RPC_STOP_MINER() {
    echo $(curl --silent -X POST -H "Content-Type: application/json" --data '{"id":"1", "method": "miner_stop"}' 0.0.0.0:${RPC_PORT} | jq -r '.result')
}

RPC_START_MINER() {
    # Requires coinbase as argument 1
    # Requires password as argument 2
    echo $(curl --silent -X POST -H "Content-Type: application/json" --data '{"id":"1", "method": "miner_start", "params": [1, "'${1}'", "'${2}'"]}' 0.0.0.0:${RPC_PORT} | jq 'if (.error != null) then .error | .message else .result end')
}

STOP_MINER() {
    # Check if the process is up
    pid=$(IS_CYPHER_RUNNING) && {
        MSG INFO "Cypher is running pid [${pid}]"
        IS_LOCAL_TCP_PORT_OPEN ${RPC_PORT} && {
            MSG INFO "Local RPC port [${RPC_PORT}/TCP] is open and listening"
            stopMiner=$(RPC_STOP_MINER)
            MSG INFO "Miner stopped [${stopMiner}]"
        } || {
            MSG INFO "Local RPC port [${RPC_PORT}/TCP] is not open or listening"
        }

        # Kill process aswell
        if [[ "${1}" == "PROCESS" ]]; then
            MSG INFO "Killing Cypher process"
            kill -9 ${pid}
        fi
    } || {
        MSG INFO "Cypher is not running"
    }
}

_START_MINER() {
    IS_LOCAL_TCP_PORT_OPEN ${RPC_PORT} && {
        MSG INFO "Local RPC port [${RPC_PORT}/TCP] is open and listening."
        # Check status
        if [[ $(GET_MINER_STATUS | grep -E "Stopped") ]]; then
            # Ask for coinbase and password
            MSG INFO "Miner currently stopped, please enter credentials."
            minerResponse="X"; while [[ "${minerResponse}" != "null" ]]; do
                SHOW_CURSOR
                printf "\n"; read -p    "Please enter coinbase address: " u_coinbase
                read -s -p "Please enter password        : " u_password; printf "\n"
                HIDE_CURSOR
                minerResponse=$(RPC_START_MINER "${u_coinbase}" "${u_password}")
                if [[ "${minerResponse}" != "null" ]]; then
                    printf "\n"; MSG WARNING "Please check your input, the miner returned:"; printf "\n"
                    echo "    ${minerResponse}"; printf "\n"
                    while true; do
                        SHOW_CURSOR; read -p "Do you wish try again? [Yes/No]: " yn; HIDE_CURSOR
                        case $yn in
                            [Yy]* ) break;;
                            [Nn]* ) minerResponse="null"; break;;
                            * ) echo "Please enter y[es] or n[o].";;
                        esac
                    done
                else
                    printf "\n"; MSG INFO "Miner started."
                    break
                fi
            done
        else
            MSG INFO "Miner already started, nothing to do."
        fi
    } || {
        MSG ERROR "Can't start miner, local RPC port [${RPC_PORT}/TCP] is not open or listening."
    }
}

START_MINER() {
    # Init
    secWait=10

    # Check if the process is already running
    pid=$(IS_CYPHER_RUNNING) && {
        MSG INFO "Cypher is already running pid [${pid}]."
    } || {
        MSG INFO "Cypher is not running, starting cypher and waiting for ${secWait} seconds."
        ./start.sh 0 &>/dev/null &
        HIDE_CURSOR
        while [ $secWait -gt 0 ]; do
            innerBar=$(printf "="'%.s' $(eval "echo {1.."$((${secWait}*5))"}"))
            outerBar="${CPurple}${BCGreen}|"$(printf %-51s ${innerBar})"| $(printf %-2s ${secWait})${NOCOL}"
            echo -ne "${outerBar}\033[0K\r"
            sleep 1
            : $((secWait--))
        done
        echo -ne "\033[0K\r"
    }

    # start miner process
    if [[ "${1}" == "PROCESS" ]]; then _START_MINER; fi
}

CHECK_PORTS() {
    # Check RPC port
    IS_LOCAL_TCP_PORT_OPEN ${RPC_PORT} && {
        MSG PASSED "Local RPC port [${RPC_PORT}/TCP] is open and listening"
    } || {
        MSG FAILED "Local RPC port [${RPC_PORT}/TCP] is not open or listening"
    }

    # Get external ip
    externalIp=$(GET_EXTERNAL_IP)

    # Check external ports
    if [ "${restricted}" != "1" ]; then
        # Check external UDP ports
        for p in "${UDPportArray[@]}"
        do
            udp=$(IS_UDP_PORT_OPEN "${externalIp}" "${p}") && {
                MSG PASSED "External [${p}/UDP] port is reachable [${udp}]"
            } || {
                MSG FAILED "Can't check external IP"
            }
        done

        # Check external TCP ports
        for p in "${TCPportArray[@]}"
        do
            udp=$(IS_TCP_PORT_OPEN "${externalIp}" "${p}") && {
                MSG PASSED "External [${p}/TCP] port is reachable [${udp}]"
            } || {
                MSG FAILED "Can't check external IP"
            }
        done
    else
        MSG WARNING "Executed script as non root user, skipping external port check"
    fi
}

MINER_HEALTHCHECK() {
    pid=$(IS_CYPHER_RUNNING) && {
        minerStatus=$(GET_MINER_STATUS)
        decimalKeyBlock=$(GET_DECIMAL_KEY_BLOCK)
        hexadecimalKeyBlock=$(DECIMAL_TO_HEXADECIMAL ${decimalKeyBlock})
        coinBase=$(GET_COINBASE)
        balance=$(GET_BALANCE ${coinBase})

        MSG INFO "Miner process (cypher) running with pid [${pid}]"
        MSG INFO "Miner status is: [${minerStatus}]"
        MSG INFO "Current keyblok in decimal [${decimalKeyBlock}] in hexadecimal [${hexadecimalKeyBlock}]"
        MSG INFO "Coinbase is: [${coinBase}]"
        MSG INFO "Balance is: hexidecimal [${balance}] decimal balance [$(HEXADECIMAL_TO_DECIMAL ${balance})] balance in cph [$(DIVIDE_BY_QUINTILLION $(HEXADECIMAL_TO_DECIMAL ${balance}) 4)]"

        IS_COINBASE_IN_COMMITTEE "${hexadecimalKeyBlock}" "${coinBase}" && {
            MSG PASSED "Coinbase is in committee for current keyblock"
        } || {
            MSG WARNING "Coinbase is NOT in committee for current keyblock"
        }

        IS_COINBASE_IN_COMMITTEE_EXCEPTION "${hexadecimalKeyBlock}" "${coinBase}" && {
            MSG WARNING "Coinbase IS in committee exception for current keyblock"
        } || {
            MSG PASSED "Coinbase is not in committee exception for current keyblock"
        }
    } || {
        MSG WARNING "Cannot perform health check, miner process not running"
    }
}

SCAN_FOR_STATUS() {
    FUNCTION_NAME="IS_COINBASE_IN_COMMITTEE"
    MESSAGE=""
    if [[ "${1}" == "EXCEPTION" ]]; then FUNCTION_NAME="${FUNCTION_NAME}_EXCEPTION"; MESSAGE=" exception"; fi

    # Check if cypher is listening
    pid=$(IS_CYPHER_RUNNING) && {
        # Get current keyblock
        currentKeyblock=$(GET_DECIMAL_KEY_BLOCK)
        MSG INFO "Current keyblock is [${currentKeyblock}]"

        u_startKeyBlock=""; u_endKeyBlock=""; while ( (! [[ "${u_startKeyBlock}" =~ ^[0-9]+$ ]] || ! [[ "${u_endKeyBlock}" =~ ^[0-9]+$ ]]) || ([[ ${u_endKeyBlock} -gt ${currentKeyblock} ]] || [[ ${u_startKeyBlock} -gt ${u_endKeyBlock} ]]) ); do
            SHOW_CURSOR
            printf "\n"
            $E "Please enter non negative start keyblock (integer) and make sure that start does not exceed end, maximum keyblock value is ${currentKeyblock}"
            read -p "Please enter start keyblock (enter defaults to 1)              : " u_startKeyBlock
            $E "Please enter non negative end keyblock (integer) and make sure that end exceeds or equals start, maximum keyblock value is ${currentKeyblock}"
            read -p "Please enter end keyblock (enter defaults to current keyblock) : " u_endKeyBlock
            printf "\n"
            HIDE_CURSOR
            u_startKeyBlock=${u_startKeyBlock:-1}
            u_endKeyBlock=${u_endKeyBlock:-${currentKeyblock}}
        done

        coinBase=$(GET_COINBASE)
        MSG INFO "Start scan for keyblock ${u_startKeyBlock} to ${u_endKeyBlock}"

        for p in $(eval echo "{${u_startKeyBlock}..${u_endKeyBlock}}"); do
            hex=$(DECIMAL_TO_HEXADECIMAL "${p}")
            IS_COINBASE_IN_COMMITTEE "${hex}" "${coinBase}" && {
               MSG INFO "KEY BLOCK ${p} ${hex} ${coinBase} in committee${MESSAGE}"
            } || {
               MSG INFO "KEY BLOCK ${p} ${hex} ${coinBase} not in committee${MESSAGE}"
            }
        done
    } || {
        MSG WARNING "Can't scan when miner process is not running"
    }
}

# CSI CUP Cursor Position (Move cursos to row n, column m) values are 1-based, and default to 1 (top left corner) if omitted
POSITION() {
    $e "\e[${1};${2}H"
}

# ESC RIS Reset to Initial State (reset terminal to its original state)
RESET_TERMINAL() {
    $e "\ec"
}

# CSI DECTCEM Hide the cursor
HIDE_CURSOR() {
    $e "\e[?25l"
}

# CSI DECTCEM Show the cursor
SHOW_CURSOR() {
    $e "\e[?25h"
}

# CSI SGR invert (Swap foreground and background colors)
INVERT() {
    $e "\e[7m"
}

# CSI SGR Not reversed (undo foreground and backgroud color swap)
UNINVERT() {
    $e "\e[27m"
}

FULLRESET_TERMINAL() {
    RESET_TERMINAL
    stty sane
    RESET_TERMINAL
}

# Special characters
# \xE2\x94\x82 vertical bar
# \xE2\x86\x91 arrow UP
# \xE2\x86\x93 arrow DOWN

MENU_HEADER() {
    # Draw the sides of the menu
    for each in $(seq 1 21);do
        $E "   \xE2\x94\x82                                                              \xE2\x94\x82 "
    done

    INVERT
    POSITION 1 5
    $E "\033[36m                           CYPHERIUM                          \033[0m"
    UNINVERT
    pid=$(IS_CYPHER_RUNNING) && {
        minerStatus=$(GET_MINER_STATUS)
        POSITION 3 5
        $E "     Cypher process is running with pid [${pid}]"
        POSITION 4 5
        $E "     Miner status [${minerStatus}]"
    } || {
        POSITION 3 5
        $E "     Cypher process not running"
        POSITION 4 5
        $E "     Miner not running"
    }
    INVERT
    POSITION 6 5
    $E "\033[36m                         SELECT OPTION                        \033[0m"
    UNINVERT

    INVERT; POSITION 8 5; $E "\033[94m     CONTROL\033[0m"; UNINVERT
    INVERT; POSITION 14 5; $E "\033[94m     CHECKS\033[0m"; UNINVERT
}

MENU_FOOTER() {
    INVERT
    POSITION 21 5
    $E "\033[36m              UP \xE2\x86\x91 \xE2\x86\x93 DOWN   \xe2\x86\xb5 ENTER - SELECT,NEXT              \033[0m"
    UNINVERT
}

MENU_ARROW() {
    # Determine keypress (up arrow, down arrow, enter)
    IFS= read -s -n1 key 2>/dev/null >&2
    if [[ $key = $ESC ]]; then
        read -s -n1 key 2>/dev/null >&2;
        if [[ $key = \[ ]]; then
            read -s -n1 key 2>/dev/null >&2

            if [[ $key = A ]]; then
                echo up
            fi

            if [[ $key = B ]]; then
                echo dn
            fi
        fi
    fi

    if [[ "$key" == "$($e \\x0A)" ]]; then
        echo enter
    fi
}

MENU_OPTIONS() {
    for each in $(seq 0 $LM); do
        M${each}
    done
}

MENU_POSITION() {
    if [[ $cur == up ]]; then
        ((i--))
    fi

    if [[ $cur == dn ]]; then
        ((i++))
    fi

    if [[ $i -lt 0   ]]; then
        i=$LM
    fi

    if [[ $i -gt $LM ]]; then
        i=0
    fi
}

REFRESH() {
    after=$((i+1))
    before=$((i-1))

    if [[ $before -lt 0 ]]; then
        before=$LM
    fi

    if [[ $after -gt $LM ]]; then
        after=0
    fi

    if [[ $j -lt $i ]]; then
        UNINVERT
        M$before
    else
        UNINVERT
        M$after
    fi

    if [[ $after -eq 0 ]] || [ $before -eq $LM ]; then
        UNINVERT
        M$before
        M$after
    fi

    j=$i
    UNINVERT
    M$before
    M$after
}

INIT() {
   FULLRESET_TERMINAL
   MENU_HEADER
   MENU_FOOTER
   MENU_OPTIONS
   HIDE_CURSOR
}

HIGHLIGHT_SELECTION() {
    REFRESH
    INVERT
    ${menuItem}
    #$b
    cur=$(MENU_ARROW)
}

ESCAPE_TO_MAIN() {
    INVERT
    $e "ENTER = main menu"
    stty -echo
    #$b
    read
    INIT
}

M0() {
    POSITION 9 10
    $e "Start miner process"
}

M1() {
    POSITION 10 10
    $e "Start mining"
}


M2() {
    POSITION 11 10
    $e "Stop miner process"
}

M3() {
    POSITION 12 10
    $e "Stop mining"
}

M4() {
    POSITION 15 10
    $e "Check ports"
}

M5() {
    POSITION 16 10
    $e "Miner healthcheck"
}

M6() {
    POSITION 17 10
    $e "Scan for committee status in keyblocks"
}

M7() {
    POSITION 18 10
    $e "Scan for committee status exception in keyblocks"
}

M8() {
    POSITION 19 10
    $e "EXIT"
}

#################################################################
#                            Precheck                           #
#################################################################
# Check root
clear
if [[ $EUID -ne 0 ]]; then
    echo "Some functions require the script to be executed with root privilege"
    while true; do
        read -p "Do you wish to continue? [Yes/No]: " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) exit;;
            * ) echo "Please enter y[es] or n[o].";;
        esac
    done
    restricted=1
fi

# Check if all required packages are installed
exitSwitch=0
for package in "${packageArray[@]}"
do
    $(PACKAGE_INSTALLED "${package}") && {
        MSG INFO "Package ${package} installed"
    } || {
        MSG WARNING "Package ${package} not installed, please run:"
        echo "sudo apt install ${package}"
        exitSwitch=1
    }
done
# Exit when not all packages are installed
if [[ ${exitSwitch} -gt 0 ]]; then exit 0; fi
HIDE_CURSOR
ESCAPE_TO_MAIN

###############################################
#                  MAIN                       #
###############################################
RESET_TERMINAL
HIDE_CURSOR
NULL=/dev/null
INIT

while [[ "$O" != " " ]]; do
    # MENU_POSITION sets i each loop
    case $i in
        0) menuItem=M0
           HIGHLIGHT_SELECTION
           if [[ $cur == enter ]]; then
               FULLRESET_TERMINAL
               HIDE_CURSOR
               START_MINER
               ESCAPE_TO_MAIN
           fi
           ;;
        1) menuItem=M1
           HIGHLIGHT_SELECTION
           if [[ $cur == enter ]]; then
               FULLRESET_TERMINAL
               HIDE_CURSOR
               START_MINER "PROCESS"
               ESCAPE_TO_MAIN
           fi
           ;;
        2) menuItem=M2
           HIGHLIGHT_SELECTION
           if [[ $cur == enter ]]; then
               FULLRESET_TERMINAL
               HIDE_CURSOR
               STOP_MINER "PROCESS"
               ESCAPE_TO_MAIN
           fi
           ;;
        3) menuItem=M3
           HIGHLIGHT_SELECTION
           if [[ $cur == enter ]]; then
               FULLRESET_TERMINAL
               HIDE_CURSOR
               STOP_MINER
               ESCAPE_TO_MAIN
           fi
           ;;
        4) menuItem=M4
           HIGHLIGHT_SELECTION
           if [[ $cur == enter ]]; then
               FULLRESET_TERMINAL
               HIDE_CURSOR
               CHECK_PORTS
               ESCAPE_TO_MAIN
           fi
           ;;
        5) menuItem=M5
           HIGHLIGHT_SELECTION
           if [[ $cur == enter ]]; then
               FULLRESET_TERMINAL
               HIDE_CURSOR
               MINER_HEALTHCHECK
               ESCAPE_TO_MAIN
           fi
           ;;
        6) menuItem=M6
           HIGHLIGHT_SELECTION
           if [[ $cur == enter ]]; then
               FULLRESET_TERMINAL
               HIDE_CURSOR
               SCAN_FOR_STATUS
               ESCAPE_TO_MAIN
           fi
           ;;
        7) menuItem=M7
           HIGHLIGHT_SELECTION
           if [[ $cur == enter ]]; then
               FULLRESET_TERMINAL
               HIDE_CURSOR
               SCAN_FOR_STATUS "EXCEPTION"
               ESCAPE_TO_MAIN
           fi
           ;;
        8) menuItem=M8
           HIGHLIGHT_SELECTION
           if [[ $cur == enter ]]; then
               HIDE_CURSOR
               FULLRESET_TERMINAL
               exit 0
           fi
           ;;
    esac
    # Determine position in the menu
    MENU_POSITION
done
