#!/usr/bin/env bash

function EnvFile {
    if [ -f ~/.patrolserver/env ];
    then
        source ~/.patrolserver/env
        LOCATE="$HOME/.patrolserver/locate.db"
    fi
}

function Args {

    optspec=":e:p:n:k:s:ci:b:hv-:"
    while getopts "$optspec" optchar; do
        case "${optchar}" in
            -)
                case "${OPTARG}" in
                    version)
                        echo "PatrolServer BashScanner $VERSION" >&2
                        exit
                        ;;
                    email)
                        EMAIL="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                        ;;
                    email=*)
                        EMAIL=${OPTARG#*=}
                        ;;
                    password)
                        PASSWORD="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                        ;;
                    password=*)
                        PASSWORD=${OPTARG#*=}
                        ;;
                    hostname)
                        HOSTNAME="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                        ;;
                    hostname=*)
                        HOSTNAME=${OPTARG#*=}
                        ;;
                    key)
                        KEY="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                        ;;
                    key=*)
                        KEY=${OPTARG#*=}
                        ;;
                    secret)
                        SECRET="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                        ;;
                    secret=*)
                        SECRET=${OPTARG#*=}
                        ;;
                    cmd)
                        CMD="true"
                        ;;
                    cmd=*)
                        CMD=${OPTARG#*=}
                        ;;
                    server_id)
                        SERVER_ID="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                        ;;
                    server_id=*)
                        SERVER_ID=${OPTARG#*=}
                        ;;
                    bucket)
                        BUCKET="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                        ;;
                    bucket=*)
                        BUCKET=${OPTARG#*=}
                        ;;
                    cron)
                        CRON="true"
                        ;;
                    cron=*)
                        CRON=${OPTARG#*=}
                        ;;
                    target)
                        MY_HOME="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                        ;;
                    target=*)
                        MY_HOME=${OPTARG#*=}
                        ;;
                    *)
                        if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
                            echo "Unknown option --${OPTARG}" >&2
                        fi
                        ;;
                esac;;
            h)
                echo "usage: $0 [-v] [--key=<value>] [--secret=<value>] [--hostname=<value>] [--cmd]" >&2
                exit 2
                ;;
            v)
                echo "PatrolServer BashScanner $VERSION" >&2
                exit
                ;;
            e)
                EMAIL=${OPTARG}
                ;;
            p)
                PASSWORD=${OPTARG}
                ;;
            n)
                HOSTNAME=${OPTARG}
                ;;
            k)
                KEY=${OPTARG}
                ;;
            s)
                SECRET=${OPTARG}
                ;;
            c)
                CMD="true"
                ;;
            i)
                SERVER_ID=${OPTARG}
                ;;
            b)
                BUCKET=${OPTARG}
                ;;
            t)
                MY_HOME=${OPTARG}
                ;;
            *)
                if [ "$OPTERR" != 1 ] || [ "${optspec:0:1}" = ":" ]; then
                    echo "Non-option argument: '-${OPTARG}'" >&2
                fi
                ;;
        esac
    done
}
