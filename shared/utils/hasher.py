import hashlib

api_key = "subDlApiUrl"

# Generate SHA-256 hash
hashed_key = hashlib.sha256(api_key.encode()).hexdigest()

# Convert hex to binary
# binary_hash = bin(int(hashed_key, 16))[2:].zfill(256)  # Remove '0b' prefix and pad to 256 bits

print(f"SHA-256 hash (binary): {hashed_key}")
