from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.user import User
from app.utils.security import (
    create_access_token,
    hash_password,
    verify_password,
)


def get_user_by_email(db: Session, email: str):
    return db.query(User).filter(User.email == email).first()


def register_user(
    db: Session,
    name: str,
    email: str,
    password: str,
    is_admin: bool = False,
) -> User:
    existing_user = get_user_by_email(db, email)
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email is already registered",
        )

    user = User(
        name=name,
        email=email,
        hashed_password=hash_password(password),
        is_admin=is_admin,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def login_user(db: Session, email: str, password: str) -> str:
    user = get_user_by_email(db, email)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )
    if not verify_password(password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )
    return create_access_token(subject=str(user.id))


def ensure_admin_user(
    db: Session,
    name: str,
    email: str,
    password: str,
) -> User:
    existing_user = get_user_by_email(db, email)

    if existing_user:
        needs_commit = False

        if existing_user.name != name:
            existing_user.name = name
            needs_commit = True

        if not existing_user.is_admin:
            existing_user.is_admin = True
            needs_commit = True

        if not verify_password(password, existing_user.hashed_password):
            existing_user.hashed_password = hash_password(password)
            needs_commit = True

        if needs_commit:
            db.commit()
            db.refresh(existing_user)

        return existing_user

    return register_user(db, name, email, password, is_admin=True)
