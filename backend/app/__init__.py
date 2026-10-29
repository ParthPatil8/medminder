import os

from flask import Flask, send_from_directory
from flask_cors import CORS

from config import Config
from .extensions import db


def create_app(overrides: dict | None = None) -> Flask:
    app = Flask(__name__)
    app.config.from_object(Config)
    if overrides:
        app.config.update(overrides)

    static_dir = os.path.join(os.path.dirname(app.root_path), "static")

    @app.get("/")
    def index():  # the web app: same origin as the API, nothing to build
        return send_from_directory(static_dir, "index.html")

    db.init_app(app)
    origins = [o.strip() for o in app.config["CORS_ORIGINS"].split(",")]
    CORS(app, resources={r"/api/*": {"origins": origins}})

    from . import models  # noqa: F401  (registers tables)
    from .routes import bp, register_errors

    app.register_blueprint(bp, url_prefix="/api")
    register_errors(app)

    with app.app_context():
        db.create_all()  # documented init procedure; see README
    return app
