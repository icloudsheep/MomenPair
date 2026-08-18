from datetime import datetime
from typing import Annotated, NoReturn

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.ext.asyncio import AsyncSession

from momen_pair.api.routes.auth import get_current_user
from momen_pair.db.session import get_session
from momen_pair.modules.accounts.service import AuthenticatedUser
from momen_pair.modules.families.models import FamilyRole
from momen_pair.modules.families.service import (
    AlreadyInFamilyError,
    CannotRemoveSelfError,
    CreatedInvitation,
    FamilyDetails,
    FamilyMemberDetails,
    FamilyNotFoundError,
    FamilyPermissionDeniedError,
    FamilyServiceError,
    InvitationDetails,
    InvitationInvalidError,
    LastAdminError,
    MemberNotFoundError,
    change_family_member_role,
    create_family,
    create_family_invitation,
    get_current_family,
    join_family,
    leave_family,
    list_family_invitations,
    list_family_members,
    remove_family_member,
    revoke_family_invitation,
)

router = APIRouter()


class CreateFamilyRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    name: str = Field(min_length=1, max_length=80)


class JoinFamilyRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    code: str = Field(min_length=16, max_length=128)


class CreateInvitationRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    expires_in_hours: int = Field(default=24, ge=1, le=168)
    max_uses: int = Field(default=1, ge=1, le=10)


class ChangeMemberRoleRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    role: FamilyRole


class FamilyResponse(BaseModel):
    model_config = ConfigDict(frozen=True)

    id: str
    name: str
    role: FamilyRole
    member_count: int


class FamilyMemberResponse(BaseModel):
    model_config = ConfigDict(frozen=True)

    user_id: str
    display_name: str
    role: FamilyRole
    joined_at: datetime


class InvitationResponse(BaseModel):
    model_config = ConfigDict(frozen=True)

    id: str
    expires_at: datetime
    max_uses: int
    used_count: int
    status: str


class CreatedInvitationResponse(InvitationResponse):
    code: str


class FamilyActionResponse(BaseModel):
    model_config = ConfigDict(frozen=True)

    status: str = "ok"


@router.get("/current", response_model=FamilyResponse)
async def current_family(
    user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_session)],
) -> FamilyResponse:
    try:
        family = await get_current_family(session, user.id)
    except FamilyServiceError as error:
        _raise_family_error(error)
    return _family_response(family)


@router.post("", response_model=FamilyResponse, status_code=status.HTTP_201_CREATED)
async def create(
    request: CreateFamilyRequest,
    user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_session)],
) -> FamilyResponse:
    try:
        family = await create_family(session, user.id, request.name)
    except FamilyServiceError as error:
        _raise_family_error(error)
    return _family_response(family)


@router.post("/join", response_model=FamilyResponse)
async def join(
    request: JoinFamilyRequest,
    user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_session)],
) -> FamilyResponse:
    try:
        family = await join_family(session, user.id, request.code)
    except FamilyServiceError as error:
        _raise_family_error(error)
    return _family_response(family)


@router.get("/current/members", response_model=list[FamilyMemberResponse])
async def members(
    user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_session)],
) -> list[FamilyMemberResponse]:
    try:
        family_members = await list_family_members(session, user.id)
    except FamilyServiceError as error:
        _raise_family_error(error)
    return [_member_response(member) for member in family_members]


@router.patch(
    "/current/members/{target_user_id}",
    response_model=FamilyMemberResponse,
)
async def change_member_role(
    target_user_id: str,
    request: ChangeMemberRoleRequest,
    user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_session)],
) -> FamilyMemberResponse:
    try:
        member = await change_family_member_role(
            session,
            user.id,
            target_user_id,
            request.role,
        )
    except FamilyServiceError as error:
        _raise_family_error(error)
    return _member_response(member)


@router.delete(
    "/current/members/{target_user_id}",
    response_model=FamilyActionResponse,
)
async def remove_member(
    target_user_id: str,
    user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_session)],
) -> FamilyActionResponse:
    try:
        await remove_family_member(session, user.id, target_user_id)
    except FamilyServiceError as error:
        _raise_family_error(error)
    return FamilyActionResponse()


@router.post("/current/leave", response_model=FamilyActionResponse)
async def leave(
    user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_session)],
) -> FamilyActionResponse:
    try:
        await leave_family(session, user.id)
    except FamilyServiceError as error:
        _raise_family_error(error)
    return FamilyActionResponse()


@router.post(
    "/current/invitations",
    response_model=CreatedInvitationResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_invitation(
    request: CreateInvitationRequest,
    user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_session)],
) -> CreatedInvitationResponse:
    try:
        invitation = await create_family_invitation(
            session,
            user.id,
            request.expires_in_hours,
            request.max_uses,
        )
    except FamilyServiceError as error:
        _raise_family_error(error)
    return _created_invitation_response(invitation)


@router.get(
    "/current/invitations",
    response_model=list[InvitationResponse],
)
async def invitations(
    user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_session)],
) -> list[InvitationResponse]:
    try:
        family_invitations = await list_family_invitations(session, user.id)
    except FamilyServiceError as error:
        _raise_family_error(error)
    return [_invitation_response(invitation) for invitation in family_invitations]


@router.delete(
    "/current/invitations/{invitation_id}",
    response_model=FamilyActionResponse,
)
async def revoke_invitation(
    invitation_id: str,
    user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_session)],
) -> FamilyActionResponse:
    try:
        await revoke_family_invitation(session, user.id, invitation_id)
    except FamilyServiceError as error:
        _raise_family_error(error)
    return FamilyActionResponse()


def _family_response(family: FamilyDetails) -> FamilyResponse:
    return FamilyResponse(
        id=family.id,
        name=family.name,
        role=family.role,
        member_count=family.member_count,
    )


def _member_response(member: FamilyMemberDetails) -> FamilyMemberResponse:
    return FamilyMemberResponse(
        user_id=member.user_id,
        display_name=member.display_name,
        role=member.role,
        joined_at=member.joined_at,
    )


def _invitation_response(invitation: InvitationDetails) -> InvitationResponse:
    return InvitationResponse(
        id=invitation.id,
        expires_at=invitation.expires_at,
        max_uses=invitation.max_uses,
        used_count=invitation.used_count,
        status=invitation.status.value,
    )


def _created_invitation_response(
    invitation: CreatedInvitation,
) -> CreatedInvitationResponse:
    details = invitation.invitation
    return CreatedInvitationResponse(
        id=details.id,
        expires_at=details.expires_at,
        max_uses=details.max_uses,
        used_count=details.used_count,
        status=details.status.value,
        code=invitation.code,
    )


def _raise_family_error(error: FamilyServiceError) -> NoReturn:
    error_type = type(error)
    code, status_code = _FAMILY_ERRORS.get(
        error_type,
        ("family_operation_failed", status.HTTP_400_BAD_REQUEST),
    )
    raise HTTPException(
        status_code=status_code,
        detail={
            "code": code,
            "message_key": f"errors.{code}",
            "parameters": {},
        },
    ) from error


_FAMILY_ERRORS: dict[type[FamilyServiceError], tuple[str, int]] = {
    FamilyNotFoundError: ("family_not_found", status.HTTP_404_NOT_FOUND),
    AlreadyInFamilyError: ("already_in_family", status.HTTP_409_CONFLICT),
    InvitationInvalidError: ("invitation_invalid", status.HTTP_404_NOT_FOUND),
    FamilyPermissionDeniedError: (
        "family_permission_denied",
        status.HTTP_403_FORBIDDEN,
    ),
    MemberNotFoundError: ("family_member_not_found", status.HTTP_404_NOT_FOUND),
    LastAdminError: ("last_family_admin", status.HTTP_409_CONFLICT),
    CannotRemoveSelfError: ("cannot_remove_self", status.HTTP_409_CONFLICT),
}
