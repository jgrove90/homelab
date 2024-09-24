import requests
import logging
import os
from cloudflare import Cloudflare
from dotenv import dotenv_values

logging.basicConfig(filename='log.txt', level=logging.INFO, 
                    format='%(asctime)s - %(levelname)s - %(message)s')

def get_public_ip() -> str:
    return requests.get("https://api.ipify.org/").text

def write_to_file(file_path: str, content: str) -> None:
    with open(file_path, "w") as file:
        file.write(content)

def read_from_file(file_path: str) -> str:
    if not os.path.exists(file_path):
        public_ip = get_public_ip()
        write_to_file(file_path, public_ip)
    with open(file_path, "r") as file:
        return file.read()

def update_cloudflare_dns_record(env: dotenv_values, public_ip: str) -> None:
    try:
        client = Cloudflare(api_email=env.get("CLOUDFLARE_EMAIL"),
                            api_key=env.get("CLOUDFLARE_API_KEY"))

        a_records = client.dns.records.list(zone_id=env.get("CLOUDFLARE_ZONE_ID"), type='A')

        for record in a_records:
            client.dns.records.update(dns_record_id=record.id, 
                                    zone_id=env.get("CLOUDFLARE_ZONE_ID"),
                                    content=public_ip,
                                    type=record.type,
                                    name=record.name,
                                    id=record.id,
                                    ttl=record.ttl) 
    except Exception as e:
        logging.error(f"{e}")

def main():
    env = dotenv_values(".env")
    public_ip = get_public_ip()
    current_ip = read_from_file("public_ip.txt")

    if current_ip != public_ip:
        write_to_file("public_ip.txt", public_ip)
        update_cloudflare_dns_record(env, public_ip)
        logging.info(f"Public IP updated from {current_ip} to {public_ip}")

if __name__ == "__main__":  
    main()