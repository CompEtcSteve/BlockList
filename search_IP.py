import ipaddress
import requests

def search_ip_in_subnets(ip, github_raw_url):
    ip_obj = ipaddress.ip_address(ip)

    # Fetch the file containing subnets from GitHub
    try:
        response = requests.get(github_raw_url)
        response.raise_for_status()  # Raise an error for bad HTTP responses
        subnets = response.text.splitlines()  # Split the file content into lines
    except requests.RequestException as e:
        print(f"Error fetching the file: {e}")
        return False

    # Search through the subnets
    for subnet in subnets:
        subnet = subnet.strip()  # Remove any extra whitespace/newlines
        try:
            network = ipaddress.ip_network(subnet, strict=False)
            if ip_obj in network:
                print(f"{ip} is in subnet {subnet}")
                return True
        except ValueError:
            #print(f"Invalid subnet format: {subnet}")
            continue

    print(f"{ip} is not in any of the subnets.")
    return False

# Main script to prompt for an IP and search for it in subnets
if __name__ == "__main__":
    ip_to_check = input("Enter an IP address to check: ")
    # Replace the URL below with the raw URL of your file on GitHub
    github_raw_url = 'https://raw.githubusercontent.com/CompEtcSteve/BlockList/master/ips.txt'
    search_ip_in_subnets(ip_to_check, github_raw_url)

    # Pause to allow viewing of output
    input("Press Enter to exit...")