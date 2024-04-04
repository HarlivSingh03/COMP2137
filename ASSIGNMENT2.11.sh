#!/bin/bash

# Function to display labeled output
printlabel() {
    echo -e "\n=============================="
    echo " $1"
    echo "=============================="
}


# Function to exit script on failure
exitonfailure() {
    if [ $? -ne 0 ]; then
        print_error "$1 failed. Exiting script"
        exit 1
    fi
}
# Function to display error messages
printerror() {
    echo -e "\n[ERROR] $1\n"
}

# Function to configure the firewall using UFW
configurefirewall() {
    # Enable UFW
    ufw enable > /dev/null 2>&1
    exit_on_failure "Enabling UFW"

    # Allow SSH on port 22 only on mgmt network
    ufw allow in on mgmt to any port 22 > /dev/null 2>&1
    exit_on_failure "Allowing SSH through UFW"

    # Allow HTTP on both interfaces
    ufw allow in on eth0 to any port 80 > /dev/null 2>&1
    ufw allow in on eth1 to any port 80 > /dev/null 2>&1
    exit_on_failure "Allowing HTTP through UFW"

    # Allow Web Proxy on both interfaces
    ufw allow in on eth0 to any port 3128 > /dev/null 2>&1
    ufw allow in on eth1 to any port 3128 > /dev/null 2>&1
    exit_on_failure "Allowing Web Proxy through UFW"
}

# Function to check if a package is installed
packageinstalled() {
    dpkg -s "$1" >/dev/null 2>&1
}

# Function to modify the netplan configuration file
modifynetplanconfig() {
    config_file="/etc/netplan/01-netcfg.yaml"
    desired_config=$(cat <<EOL
network:
  version: 2
  renderer: networkd
  ethernets:
    eth1:
      addresses: [192.168.16.21/24]
      gateway4: 192.168.16.1
      nameservers:
        addresses: [192.168.16.1]
        
EOL
    )

    echo "$desired_config" > "$config_file"
}



# Function to create user accounts and generate SSH keys
createuseraccounts() {
    # User list
    users=("dennis" "aubrey" "captain" "snibbles" "brownie" "scooter" "sandy" "perrier" "cindy" "tiger" "yoda")

    for user in "${users[@]}"; do
        # Check if user exists
        getent passwd "$user" >/dev/null 2>&1

        # Skip adding user if they already exist
        if [ $? -eq 0 ]; then
            echo "$user already exists; skipping $user creation"
        else
            # Add user with home directory and bash shell
            useradd -m -s /bin/bash "$user" 2>/dev/null
            exit_on_failure "Adding user $user"
            echo "User $user was successfully created!"
        fi

        # Check if user already has RSA key
        if [[ -f "/home/$user/.ssh/id_rsa" ]]; then
            echo "RSA key already exists for $user"
        else
            # Generate RSA key pair for the user
            sudo -u "$user" ssh-keygen -q -t rsa -f "/home/$user/.ssh/id_rsa" -N ""
            exit_on_failure "Generating RSA key for $user"
            cat "/home/$user/.ssh/id_rsa.pub" >> "/home/$user/.ssh/authorized_keys"
        fi

        # Check if user already has ed25519 key
        if [[ -f "/home/$user/.ssh/id_ed25519" ]]; then
            echo "ed25519 key already exists for $user"
        else
            # Generate ed25519 key pair for the user
            sudo -u "$user" ssh-keygen -t ed25519 -f "/home/$user/.ssh/id_ed25519" -N ""
            exit_on_failure "Generating ed25519 key for $user"
            cat "/home/$user/.ssh/id_ed25519.pub" >> "/home/$user/.ssh/authorized_keys"
        fi

        echo "$user SSH key configuration successful."
    done

    # Add dennis to sudo group if not already in
    id dennis | grep sudo >/dev/null 2>&1 || (usermod -aG sudo dennis && echo "dennis was added to sudo group")
    exit_on_failure "Adding dennis to sudo group"

    # Add additional SSH key for dennis if not already present
    grep "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm" "/home/dennis/.ssh/authorized_keys" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm" >> "/home/dennis/.ssh/authorized_keys"
        exit_on_failure "Adding additional private key for user dennis"
        echo "Added additional key to authorized_keys for dennis"
    fi
}

# Main function to perform system modifications
main() {
    print_label "Checking system configuration"

    # Check if netplan file exists
    if [[ ! -f "/etc/netplan/01-netcfg.yaml" ]]; then
        print_error "Netplan configuration file not found."
        exit 1
    fi

    # Check if apache2 and squid packages are installed
    if ! package_installed "apache2" || ! package_installed "squid"; then
        print_error "Apache2 or Squid package is not installed."
        exit 1
    fi

    print_label "Performing necessary modifications"

    # Modify netplan configuration
    modify_netplan_config

    # Configure firewall using UFW
    configure_firewall

    # Create user accounts and generate SSH keys
    create_user_accounts

    print_label "Testing changes"


    print_label "Applying changes"

    # Display information about applied changes
    echo "Netplan configuration applied."
    echo "Firewall configured using UFW."
    echo "User accounts created and SSH keys generated."

  
}

# Run main function
main

exit 0

