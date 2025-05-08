import requests
import os

API_KEY = "lKx5GNtBO24IWpnpW7FvfwHclOBxCc2T"

def search_subtitles(movie_name: str):
    """Search for subtitles for the given movie name."""
    url = f"https://api.subdl.com/search?query={movie_name}"
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Accept": "application/x-subrip",
    }

    response = requests.get(url, headers=headers)
    
    if response.status_code == 200:
        return response.json()
    else:
        print(f"Error: {response.status_code}, {response.text}")
        return None

def download_subtitle(subtitle_url: str, output_path: str):
    """Download subtitle from the provided URL."""
    response = requests.get(subtitle_url)
    
    if response.status_code == 200:
        with open(output_path, 'wb') as file:
            file.write(response.content)
        print(f"✅ Subtitle downloaded to {output_path}")
    else:
        print(f"Error: {response.status_code}, {response.text}")

def fetch_and_download_subtitle(movie_name: str, output_dir="."):
    """Fetch subtitles and download the first available result."""
    print(f"Searching for subtitles for: {movie_name}")

    subtitles = search_subtitles(movie_name)
    
    if subtitles is None:
        print("❌ Failed to fetch subtitle data.")
        return

    if 'results' not in subtitles:
        print(f"❌ Unexpected API response: {subtitles}")
        return
    
    available_subtitles = [movie for movie in subtitles['results'] if movie['subtitles_count'] > 0]
    
    if len(available_subtitles) == 0:
        print("❌ No subtitles found.")
        return
    
    # Select the first movie with available subtitles
    selected_movie = available_subtitles[0]
    print(f"Found subtitles for: {selected_movie['name']} ({selected_movie['year']})")

    # Set output file path
    output_file = os.path.join(output_dir, f"{movie_name}.srt")
    
    # Download the subtitle file
    download_subtitle(selected_movie['poster_url'], output_file)


if __name__ == "__main__":
    # Ask the user for movie name input
    movie_name = input("Enter the name of the movie: ")
    
    fetch_and_download_subtitle(movie_name)
