import hashlib

api_key = "lKx5GNtBO24IWpnpW7FvfwHclOBxCc2T"

# Generate SHA-256 hash
hashed_key = hashlib.sha256(api_key.encode()).hexdigest()

# Convert hex to binary


print(f"SHA-256 hash (binary): {hashed_key}")
