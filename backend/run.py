from app import create_app

app = create_app()

if __name__ == "__main__":
    # 0.0.0.0 lets a phone on the same Wi-Fi reach the API via your LAN IP.
    app.run(host="0.0.0.0", port=5000, debug=True)
