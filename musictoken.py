import datetime
import jwt

secret = """-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQgPpBH55NVu8i9gL5k
JC7TSdoxO7jkn8RDBotXoSJMR/igCgYIKoZIzj0DAQehRANCAAR7JD9r73OoIO7D
6zVsaVyb73gz7o5WXdypYBkRN1yNjS2L9Jnh7OmaTFmELycySlps47Cvo+Ay2DyF
laTE9I00
-----END PRIVATE KEY-----"""
keyId = "U7VKA3M32R"      # your Key ID from Apple Developer
teamId = "3FNXL58H25"     # your Team ID from Apple Developer
alg = 'ES256'

time_now = datetime.datetime.now()
time_expired = datetime.datetime.now() + datetime.timedelta(hours=4380)  # ~6 months

headers = {
    "alg": alg,
    "kid": keyId
}

payload = {
    "iss": teamId,
    "exp": int(time_expired.timestamp()),
    "iat": int(time_now.timestamp())
}

if __name__ == "__main__":
    token = jwt.encode(payload, secret, algorithm=alg, headers=headers)

    print("----TOKEN----")
    print(token)

    print("----CURL----")
    print(f"curl -v -H 'Authorization: Bearer {token}' \"https://api.music.apple.com/v1/catalog/us/artists/36954\" ")
