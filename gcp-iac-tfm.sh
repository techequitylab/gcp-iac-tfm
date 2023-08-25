#!/bin/bash
# 
# Copyright 2019-2021 Shiyghan Navti. Email shiyghan@techequity.company
# 
#################################################################################
##############                   Explore Terraform                ###############
#################################################################################

function ask_yes_or_no() {
    read -p "$1 ([y]yes to preview, [n]o to create, [d]del to delete): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        n|no)  echo "no" ;;
        d|del) echo "del" ;;
        *)     echo "yes" ;;
    esac
}

function ask_yes_or_no_proj() {
    read -p "$1 ([y]es to change, or any key to skip): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

clear
MODE=1
export TRAINING_ORG_ID=$(gcloud organizations list --format 'value(ID)' --filter="displayName:techequity.training" 2>/dev/null)
export ORG_ID=$(gcloud projects get-ancestors $GCP_PROJECT --format 'value(ID)' 2>/dev/null | tail -1 )
export GCP_PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)  

echo
echo
echo -e "                        👋  Welcome to Cloud Sandbox! 💻"
echo 
echo -e "              *** PLEASE WAIT WHILE LAB UTILITIES ARE INSTALLED ***"
sudo apt-get -qq install pv > /dev/null 2>&1
echo 
export SCRIPTPATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

mkdir -p `pwd`/gcp-iac-tfm
export SCRIPTNAME=gcp-iac-tfm.sh
export PROJDIR=`pwd`/gcp-iac-tfm

if [ -f "$PROJDIR/.env" ]; then
    source $PROJDIR/.env
else
cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=europe-west3
export GCP_ZONE=europe-west3-a
EOF
source $PROJDIR/.env
fi

# Display menu options
while :
do
clear
cat<<EOF
=============================================
Menu for Exploring Terraform   
---------------------------------------------
Please enter number to select your choice:
(1) Enable APIs 
(2) Configure terraform 
(3) Configure service accounts
(4) Create bucket and configure network
(5) Update network  
(6) Configure firewall
(G) Launch user guide
(Q) Quit
-----------------------------------------------------------------------------
EOF
echo "Steps performed${STEP}"
echo
echo "What additional step do you want to perform, e.g. enter 0 to select the execution mode?"
read
clear
case "${REPLY^^}" in

"0")
start=`date +%s`
source $PROJDIR/.env
echo
echo "Do you want to run script in preview mode?"
export ANSWER=$(ask_yes_or_no "Are you sure?")
cd $HOME
if [[ ! -z "$TRAINING_ORG_ID" ]]  &&  [[ $ORG_ID == "$TRAINING_ORG_ID" ]]; then
    export STEP="${STEP},0"
    MODE=1
    if [[ "yes" == $ANSWER ]]; then
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    else 
        if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
            echo 
            echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
            echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
        else
            while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                echo 
                echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                gcloud auth login  --brief --quiet
                export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                if [[ $ACCOUNT != "" ]]; then
                    echo
                    echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                    read GCP_PROJECT
                    gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                    sleep 3
                    export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                fi
            done
            gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
            sleep 2
            gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
            gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
            gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
        fi
        export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
        cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=$GCP_REGION
export GCP_ZONE=$GCP_ZONE
EOF
        gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
        echo
        echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
        echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
        echo "*** Google Cloud zone is $GCP_ZONE ***" | pv -qL 100
        echo
        echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
        echo "*** $PROJDIR/.env ***" | pv -qL 100
        if [[ "no" == $ANSWER ]]; then
            MODE=2
            echo
            echo "*** Create mode is active ***" | pv -qL 100
        elif [[ "del" == $ANSWER ]]; then
            export STEP="${STEP},0"
            MODE=3
            echo
            echo "*** Resource delete mode is active ***" | pv -qL 100
        fi
    fi
else 
    if [[ "no" == $ANSWER ]] || [[ "del" == $ANSWER ]] ; then
        export STEP="${STEP},0"
        if [[ -f $SCRIPTPATH/.${SCRIPTNAME}.secret ]]; then
            echo
            unset password
            unset pass_var
            echo -n "Enter access code: " | pv -qL 100
            while IFS= read -p "$pass_var" -r -s -n 1 letter
            do
                if [[ $letter == $'\0' ]]
                then
                    break
                fi
                password=$password"$letter"
                pass_var="*"
            done
            while [[ -z "${password// }" ]]; do
                unset password
                unset pass_var
                echo
                echo -n "You must enter an access code to proceed: " | pv -qL 100
                while IFS= read -p "$pass_var" -r -s -n 1 letter
                do
                    if [[ $letter == $'\0' ]]
                    then
                        break
                    fi
                    password=$password"$letter"
                    pass_var="*"
                done
            done
            export PASSCODE=$(cat $SCRIPTPATH/.${SCRIPTNAME}.secret | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 -salt -pass pass:$password 2> /dev/null)
            if [[ $PASSCODE == 'AccessVerified' ]]; then
                MODE=2
                echo && echo
                echo "*** Access code is valid ***" | pv -qL 100
                if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
                    echo 
                    echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
                    echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
                else
                    while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                        echo 
                        echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                        gcloud auth login  --brief --quiet
                        export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                        if [[ $ACCOUNT != "" ]]; then
                            echo
                            echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                            read GCP_PROJECT
                            gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                            sleep 5
                            export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                        fi
                    done
                    gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
                    sleep 2
                    gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
                    gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
                    gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
                    gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
                fi
                export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
                cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=$GCP_REGION
export GCP_ZONE=$GCP_ZONE
EOF
                gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
                echo
                echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
                echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
                echo "*** Google Cloud zone is $GCP_ZONE ***" | pv -qL 100
                echo
                echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
                echo "*** $PROJDIR/.env ***" | pv -qL 100
                if [[ "no" == $ANSWER ]]; then
                    MODE=2
                    echo
                    echo "*** Create mode is active ***" | pv -qL 100
                elif [[ "del" == $ANSWER ]]; then
                    export STEP="${STEP},0"
                    MODE=3
                    echo
                    echo "*** Resource delete mode is active ***" | pv -qL 100
                fi
            else
                echo && echo
                echo "*** Access code is invalid ***" | pv -qL 100
                echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
                echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
                echo
                echo "*** Command preview mode is active ***" | pv -qL 100
            fi
        else
            echo
            echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
            echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
            echo
            echo "*** Command preview mode is active ***" | pv -qL 100
        fi
    else
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    fi
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"1")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},1i"
    echo
    echo "$ gcloud services enable --project=\$GCP_PROJECT compute.googleapis.com cloudresourcemanager.googleapis.com # to enable APIs" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},1"
    echo
    echo "$ gcloud services enable --project=$GCP_PROJECT compute.googleapis.com cloudresourcemanager.googleapis.com # to enable APIs" | pv -qL 100
    gcloud services enable --project=$GCP_PROJECT compute.googleapis.com cloudresourcemanager.googleapis.com
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},1x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},1i"
    echo
    echo "1. Enable APIs" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"2")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},2i"        
    echo
    echo "$ cat <<EOF > \$PROJDIR/terraform.tfvars # to create terraform variables file
project_id=\"\$GCP_PROJECT\" 
EOF" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},2" 
    echo
    rm -rf /tmp/terraform-codelab
    echo "$ git clone https://github.com/morgante/terraform-codelab.git /tmp/terraform-codelab # to clone repo" | pv -qL 100
    git clone https://github.com/morgante/terraform-codelab.git /tmp/terraform-codelab
    echo
    echo "$ cp -rf /tmp/terraform-codelab/lab-networking $PROJDIR # to copy configuration files" | pv -qL 100
    cp -rf /tmp/terraform-codelab/lab-networking $PROJDIR
    cd $PROJDIR     
    echo
    echo "$ cat <<EOF > $PROJDIR/terraform.tfvars # to create terraform variables file
project_id=\"$GCP_PROJECT\" 
EOF" | pv -qL 100
cat <<EOF > $PROJDIR/terraform.tfvars # to create terraform variables file
project_id="$GCP_PROJECT" 
EOF
    cp terraform.tfvars lab-networking 
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},2x"
    echo
    echo "$ rm -rf $PROJDIR/lab-networking # to delete configuration files" | pv -qL 100
    rm -rf $PROJDIR/lab-networking
else
    export STEP="${STEP},2i"
    echo
    echo "1. Clone repository" | pv -qL 100
    echo "2. Create terraform variables file" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"3")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},3i"        
    echo
    echo "$ gcloud iam service-accounts create terraform # to create the service account" | pv -qL 100
    echo
    echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member serviceAccount:terraform@\$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner # to grant Service Account the Owner role on project" | pv -qL 100
    echo
    echo "$ gcloud iam service-accounts keys create \$PROJDIR/lab-networking/credentials.json --iam-account=terraform@\$GCP_PROJECT.iam.gserviceaccount.com --key-file-type=json # to create the service account" | pv -qL 100
    echo
    echo "$ cat <<EOF > \$PROJDIR/provider.tf # to create bucket
provider \"google\" {
  project = \"\${var.project_id}\"
  credentials = \"\${file(\"credentials.json\")}\"
}
EOF" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},3"        
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    cd $PROJDIR     
    echo
    echo "$ gcloud iam service-accounts create terraform # to create the service account" | pv -qL 100
    gcloud iam service-accounts create terraform
    echo
    echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:terraform@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner # to grant Service Account the Owner role on project" | pv -qL 100
    gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:terraform@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner
    echo
    echo "$ gcloud iam service-accounts keys create $PROJDIR/lab-networking/credentials.json --iam-account=terraform@$GCP_PROJECT.iam.gserviceaccount.com --key-file-type=json # to create the service account" | pv -qL 100
    gcloud iam service-accounts keys create $PROJDIR/lab-networking/credentials.json --iam-account=terraform@$GCP_PROJECT.iam.gserviceaccount.com --key-file-type=json
    echo
    echo "$ cat <<EOF > $PROJDIR/provider.tf # to create bucket
provider \"google\" {
  project = \"\${var.project_id}\"
  credentials = \"\${file(\"credentials.json\")}\"
}
EOF" | pv -qL 100
cat <<EOF > $PROJDIR/provider.tf # to create bucket
provider "google" {
  project = "\${var.project_id}"
  credentials = "\${file("credentials.json")}"
}
EOF
    echo
    echo "$ cp provider.tf lab-networking # to configure provider" | pv -qL 100
    cp provider.tf lab-networking
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},3x"        
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    echo
    echo "*** Nothing to delete ***"
else
    export STEP="${STEP},3i"
    echo
    echo "1. Create terraform service account" | pv -qL 100
    echo "2. Grant service account Owner role" | pv -qL 100
    echo "3. Create the service account" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"4")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},4i"        
    echo
    echo "$ gsutil mb gs://\${GCP_PROJECT}-state-bucket # to create a new bucket to store Terraform state" | pv -qL 100
    echo
    echo "$ cat <<EOF > \$PROJDIR/backend.tf # to create bucket
terraform {
  backend \"gcs\" {
    bucket = \"\${GCP_PROJECT}-state-bucket\"
    prefix = \"terraform/lab/network\"
  }
}
EOF" | pv -qL 100
    echo
    echo "$ terraform init -reconfigure # to initialize Terraform" | pv -qL 100
    echo
    echo "$ terraform plan -out \$PROJDIR/backend.out -compact-warnings # to validate configuration syntax and preview action" | pv -qL 100
    echo
    echo "$ terraform apply -auto-approve # to execute terraform and apply changes" | pv -qL 100
    echo
    echo "$ terraform show # to display resources" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},4"        
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    cd $PROJDIR      
    echo
    echo "$ gsutil mb gs://${GCP_PROJECT}-state-bucket # to create a new bucket to store Terraform state" | pv -qL 100
    gsutil mb gs://${GCP_PROJECT}-state-bucket
    echo
    echo "$ cat <<EOF > $PROJDIR/backend.tf # to create bucket
terraform {
  backend \"gcs\" {
    bucket = \"${GCP_PROJECT}-state-bucket\"
    prefix = \"terraform/lab/network\"
  }
}
EOF" | pv -qL 100
cat <<EOF > $PROJDIR/backend.tf # to create bucket
terraform {
  backend "gcs" {
    bucket = "${GCP_PROJECT}-state-bucket"
    prefix = "terraform/lab/network"
  }
}
EOF
    cp backend.tf lab-networking 
    cd $PROJDIR/lab-networking
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ rm -rf .terraform # to clean local terraform state" | pv -qL 100
    rm -rf .terraform
    echo
    export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/lab-networking/credentials.json
    echo "$ terraform init # to initialize Terraform" | pv -qL 100
    terraform init 
    echo
    echo "$ terraform plan -out $PROJDIR/backend.out -compact-warnings # to validate configuration syntax and preview action" | pv -qL 100
    terraform plan -out $PROJDIR/backend.out -compact-warnings
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ terraform apply -auto-approve # to execute terraform and apply changes" | pv -qL 100
    terraform apply -auto-approve 
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ terraform show # to display resources" | pv -qL 100
    terraform show
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},4x"        
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    cd $PROJDIR      
    echo
    echo "$ gcloud storage rm --recursive gs://${GCP_PROJECT}-state-bucket # to delete bucket" | pv -qL 100
    gcloud storage rm --recursive gs://${GCP_PROJECT}-state-bucket
else
    export STEP="${STEP},4i"
    echo
    echo "1. Create bucket to store terraform state" | pv -qL 100
    echo "2. Configure backend.tf" | pv -qL 100
    echo "3. Initialize Terraform" | pv -qL 100
    echo "4. Validate configuration syntax and preview action" | pv -qL 100
    echo "5. Execute terraform and apply changes" | pv -qL 100
    echo "6. Display resources" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"5")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},5i"        
    echo
    echo "$ cat <<EOF > \$PROJDIR/network.tf # to create network
module \"vpc\" {
    source  = \"terraform-google-modules/network/google\"
    version = \"~> 0.4.0\"

    project_id   = \"\${google_project_service.compute.project}\"
    network_name = \"my-custom-network\"

    subnets = [
    {
        subnet_name   = \"proja-subnet\"
        subnet_ip     = \"10.10.10.0/24\"
        subnet_region = \"us-west1\"
    },
    {
        subnet_name   = \"projb-subnet\"
        subnet_ip     = \"10.10.30.0/24\"
        subnet_region = \"us-west1\"
    },
    {
        subnet_name   = \"gke-subnet\"
        subnet_ip     = \"10.10.40.0/24\"
        subnet_region = \"us-west1\"
    },
    ]

    secondary_ranges = {
        proja-subnet = []

        projb-subnet = []
    
        gke-subnet = [
        {
            range_name    = \"gke-pods-range\"
            ip_cidr_range = \"192.168.64.0/24\"
        },
        ]
    }
}
EOF" | pv -qL 100
    echo
    echo "$ terraform init # to initialize Terraform" | pv -qL 100
    echo
    echo "$ terraform plan -out \$PROJDIR/network.out -compact-warnings # to validate configuration syntax and preview action" | pv -qL 100
    echo
    echo "$ terraform apply -auto-approve # to execute terraform and apply changes" | pv -qL 100
    echo
    echo "$ terraform show # to display resources" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},5"        
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    cd $PROJDIR
    echo
    echo "$ cat <<EOF > $PROJDIR/network.tf # to create network
module \"vpc\" {
    source  = \"terraform-google-modules/network/google\"
    version = \"~> 0.4.0\"

    project_id   = \"\${google_project_service.compute.project}\"
    network_name = \"my-custom-network\"

    subnets = [
    {
        subnet_name   = \"proja-subnet\"
        subnet_ip     = \"10.10.10.0/24\"
        subnet_region = \"us-west1\"
    },
    {
        subnet_name   = \"projb-subnet\"
        subnet_ip     = \"10.10.30.0/24\"
        subnet_region = \"us-west1\"
    },
    {
        subnet_name   = \"gke-subnet\"
        subnet_ip     = \"10.10.40.0/24\"
        subnet_region = \"us-west1\"
    },
    ]

    secondary_ranges = {
        proja-subnet = []

        projb-subnet = []
    
        gke-subnet = [
        {
            range_name    = \"gke-pods-range\"
            ip_cidr_range = \"192.168.64.0/24\"
        },
        ]
    }
}
EOF" | pv -qL 100
    echo
    cat <<EOF > network.tf # to create network
module "vpc" {
    source  = "terraform-google-modules/network/google"

    project_id   = "\${google_project_service.compute.project}"
    network_name = "my-custom-network"

    subnets = [
    {
        subnet_name   = "proja-subnet"
        subnet_ip     = "10.10.10.0/24"
        subnet_region = "us-west1"
    },
    {
        subnet_name   = "projb-subnet"
        subnet_ip     = "10.10.30.0/24"
        subnet_region = "us-west1"
    },
    {
        subnet_name   = "gke-subnet"
        subnet_ip     = "10.10.40.0/24"
        subnet_region = "us-west1"
    },
    ]

    secondary_ranges = {
        proja-subnet = []

        projb-subnet = []
    
        gke-subnet = [
        {
            range_name    = "gke-pods-range"
            ip_cidr_range = "192.168.64.0/24"
        },
        ]
    }
}
EOF
    cp network.tf lab-networking 
    cd $PROJDIR/lab-networking 
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ terraform init # to initialize Terraform" | pv -qL 100
    terraform init
    echo
    echo "$ terraform plan -out $PROJDIR/network.out -compact-warnings # to validate configuration syntax and preview action" | pv -qL 100
    terraform plan -out $PROJDIR/network.out -compact-warnings 
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ terraform apply -auto-approve # to execute terraform and apply changes" | pv -qL 100
    terraform apply -auto-approve
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ terraform show # to display resources" | pv -qL 100
    terraform show
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},5x"        
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    echo
    cd $PROJDIR/lab-networking 
    echo "$ terraform destroy -auto-approve # to execute terraform and apply changes" | pv -qL 100
    terraform destroy -auto-approve
else
    export STEP="${STEP},5i"
    echo
    echo "1. Configure network.tf" | pv -qL 100
    echo "2. Initialize terraform" | pv -qL 100
    echo "3. Validate configuration syntax and preview action" | pv -qL 100
    echo "4. Execute terraform and apply changes" | pv -qL 100
    echo "5. Display resources" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"6")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},6i"        
    echo
    echo "$ cat <<EOF > \$PROJDIR/network.tf # to create network
resource \"google_compute_firewall\" \"allow-ping\" {
    name    = \"allow-ping\"
    network = \"\${module.vpc.network_name}\"
    project = \"\${google_project_service.compute.project}\"

    allow {
        protocol = \"icmp\"
    }

    source_ranges = [\"0.0.0.0/0\"]
    target_tags   = [\"allow-ping\"]
}

resource \"google_compute_firewall\" \"allow-ssh\" {
    name    = \"allow-ssh\"
    network = \"\${module.vpc.network_name}\"
    project = \"\${google_project_service.compute.project}\"

    allow {
        protocol = \"tcp\"
        ports    = [\"22\"]
    }

    source_ranges = [\"0.0.0.0/0\"]
    target_tags   = [\"allow-ssh\"]
}

resource \"google_compute_firewall\" \"allow-http\" {
    name    = \"allow-http\"
    network = \"\${module.vpc.network_name}\"
    project = \"\${google_project_service.compute.project}\"

    allow {
        protocol = \"tcp\"
        ports    = [\"80\", \"443\"]  # Edit this line
    }

    # Allow traffic from everywhere to instances with an http-server tag
    source_ranges = [\"0.0.0.0/0\"]
    target_tags   = [\"allow-http\"]
}
EOF" | pv -qL 100
    echo
    echo "$ terraform init # to initialize Terraform" | pv -qL 100
    echo
    echo "$ terraform plan -out \$PROJDIR/firewall.out -compact-warnings # to validate configuration syntax and preview action" | pv -qL 100
    echo
    echo "$ terraform apply -auto-approve # to execute terraform and apply changes" | pv -qL 100
    echo
    echo "$ terraform show # to display resources" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},6"        
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    cd $PROJDIR      
    echo
    echo "$ cat <<EOF > $PROJDIR/network.tf # to create network
resource \"google_compute_firewall\" \"allow-ping\" {
    name    = \"allow-ping\"
    network = \"\${module.vpc.network_name}\"
    project = \"\${google_project_service.compute.project}\"

    allow {
        protocol = \"icmp\"
    }

    source_ranges = [\"0.0.0.0/0\"]
    target_tags   = [\"allow-ping\"]
}

resource \"google_compute_firewall\" \"allow-ssh\" {
    name    = \"allow-ssh\"
    network = \"\${module.vpc.network_name}\"
    project = \"\${google_project_service.compute.project}\"

    allow {
        protocol = \"tcp\"
        ports    = [\"22\"]
    }

    source_ranges = [\"0.0.0.0/0\"]
    target_tags   = [\"allow-ssh\"]
}

resource \"google_compute_firewall\" \"allow-http\" {
    name    = \"allow-http\"
    network = \"\${module.vpc.network_name}\"
    project = \"\${google_project_service.compute.project}\"

    allow {
        protocol = \"tcp\"
        ports    = [\"80\", \"443\"]  # Edit this line
    }

    # Allow traffic from everywhere to instances with an http-server tag
    source_ranges = [\"0.0.0.0/0\"]
    target_tags   = [\"allow-http\"]
}
EOF" | pv -qL 100
cat <<EOF > $PROJDIR/firewall.tf # to create network
resource "google_compute_firewall" "allow-ping" {
    name    = "allow-ping"
    network = "\${module.vpc.network_name}"
    project = "\${google_project_service.compute.project}"

    allow {
        protocol = "icmp"
    }

    source_ranges = ["0.0.0.0/0"]
    target_tags   = ["allow-ping"]
}

resource "google_compute_firewall" "allow-ssh" {
    name    = "allow-ssh"
    network = "\${module.vpc.network_name}"
    project = "\${google_project_service.compute.project}"

    allow {
        protocol = "tcp"
        ports    = ["22"]
    }

    source_ranges = ["0.0.0.0/0"]
    target_tags   = ["allow-ssh"]
}

resource "google_compute_firewall" "allow-http" {
    name    = "allow-http"
    network = "\${module.vpc.network_name}"
    project = "\${google_project_service.compute.project}"

    allow {
        protocol = "tcp"
        ports    = ["80", "443"]  # Edit this line
    }

    # Allow traffic from everywhere to instances with an http-server tag
    source_ranges = ["0.0.0.0/0"]
    target_tags   = ["allow-http"]
}
EOF
    cp firewall.tf lab-networking 
    cd $PROJDIR/lab-networking 
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ terraform init # to initialize Terraform" | pv -qL 100
    terraform init
    echo
    echo "$ terraform plan -out $PROJDIR/firewall.out -compact-warnings # to validate configuration syntax and preview action" | pv -qL 100
    terraform plan -out $PROJDIR/firewall.out -compact-warnings
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ terraform apply -auto-approve # to execute terraform and apply changes" | pv -qL 100
    terraform apply -auto-approve
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ terraform show # to display resources" | pv -qL 100
    terraform show
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},6x"        
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    echo
    cd $PROJDIR/lab-networking 
    echo "$ terraform destroy -auto-approve # to delete configuration" | pv -qL 100
    terraform destroy -auto-approve
else
    export STEP="${STEP},6i"
    echo
    echo "1. Configure firewall.tf" | pv -qL 100
    echo "2. Initialize terraform" | pv -qL 100
    echo "3. Validate configuration syntax and preview action" | pv -qL 100
    echo "4. Execute terraform and apply changes" | pv -qL 100
    echo "5. Display resources" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"-7")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},7i"        
    echo
    echo "$ cat <<EOF > \$PROJDIR/outputs.tf # to create output
output \"network_name\" {
    value = \"\${module.vpc.network_name}\"
}
output \"proja_subnet_name\" {
    value = \"\${module.vpc.subnets_names[0]}\"
}
output \"projb_subnet_name\" {
    value = \"\${module.vpc.subnets_names[1]}\"
}
output \"gke_subnet_name\" {
    value = \"\${module.vpc.subnets_names[2]}\"
}
EOF" | pv -qL 100
    echo
    echo "$ terraform init # to initialize Terraform" | pv -qL 100
    echo
    echo "$ terraform plan -out \$PROJDIR/outputs.out -compact-warnings # to validate configuration syntax and preview action" | pv -qL 100
    echo
    echo "$ terraform apply -auto-approve # to execute terraform and apply changes" | pv -qL 100
    echo
    echo "$ terraform show # to display resources" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},7"        
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    cd $PROJDIR      
    echo
    echo "$ cat <<EOF > $PROJDIR/outputs.tf # to create output
output \"network_name\" {
    value = \"\${module.vpc.network_name}\"
}
output \"proja_subnet_name\" {
    value = \"\${module.vpc.subnets_names[0]}\"
}
output \"projb_subnet_name\" {
    value = \"\${module.vpc.subnets_names[1]}\"
}
output \"gke_subnet_name\" {
    value = \"\${module.vpc.subnets_names[2]}\"
}
EOF" | pv -qL 100
    cat <<EOF > $PROJDIR/outputs.tf # to create output
output "network_name" {
    value = "\${module.vpc.network_name}"
}
output "proja_subnet_name" {
    value = "\${module.vpc.subnets_names[0]}"
}
output "projb_subnet_name" {
    value = "\${module.vpc.subnets_names[1]}"
}
output "gke_subnet_name" {
    value = "\${module.vpc.subnets_names[2]}"
}
EOF
    cp outputs.tf lab-networking 
    cd $PROJDIR/lab-networking 
    echo
    echo "$ terraform init # to initialize Terraform" | pv -qL 100
    terraform init
    echo
    echo "$ terraform plan -out $PROJDIR/outputs.out -compact-warnings # to validate configuration syntax and preview action" | pv -qL 100
    terraform plan -out $PROJDIR/outputs.out -compact-warnings
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ terraform apply -auto-approve # to execute terraform and apply changes" | pv -qL 100
    terraform apply -auto-approve
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ terraform show # to display resources" | pv -qL 100
    terraform show
else
    export STEP="${STEP},7i"
    echo
    echo "1. Configure outputs.tf" | pv -qL 100
    echo "2. Initialize terraform" | pv -qL 100
    echo "3. Validate configuration syntax and preview action" | pv -qL 100
    echo "4. Execute terraform and apply changes" | pv -qL 100
    echo "5. Display resources" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"R")
echo
echo "
  __                      __                              __                               
 /|            /         /              / /              /                 | /             
( |  ___  ___ (___      (___  ___        (___           (___  ___  ___  ___|(___  ___      
  | |___)|    |   )     |    |   )|   )| |    \   )         )|   )|   )|   )|   )|   )(_/_ 
  | |__  |__  |  /      |__  |__/||__/ | |__   \_/       __/ |__/||  / |__/ |__/ |__/  / / 
                                 |              /                                          
"
echo "
We are a group of information technology professionals committed to driving cloud 
adoption. We create cloud skills development assets during our client consulting 
engagements, and use these assets to build cloud skills independently or in partnership 
with training organizations.
 
You can access more resources from our iOS and Android mobile applications.

iOS App: https://apps.apple.com/us/app/tech-equity/id1627029775
Android App: https://play.google.com/store/apps/details?id=com.techequity.app

Email:support@techequity.cloud 
Web: https://techequity.cloud

Ⓒ Tech Equity 2022" | pv -qL 100
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"G")
cloudshell launch-tutorial $SCRIPTPATH/.tutorial.md
;;

"Q")
echo
exit
;;
"q")
echo
exit
;;
* )
echo
echo "Option not available"
;;
esac
sleep 1
done
