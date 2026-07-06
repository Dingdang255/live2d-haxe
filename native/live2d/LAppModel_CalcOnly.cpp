/**
 * Live2D Cubism SDK for Native - CalcOnly version
 * Simplified LAppModel implementation - parameter calculation only, no rendering
 * 
 * Copyright(c) Live2D Inc. All rights reserved.
 * Use of this source code is governed by the Live2D Open Software license.
 */

#include "LAppModel_CalcOnly.hpp"
#include <fstream>
#include <vector>
#include <CubismModelSettingJson.hpp>
#include <Motion/CubismMotion.hpp>
#include <Physics/CubismPhysics.hpp>
#include <CubismDefaultParameterId.hpp>
#include <Utils/CubismString.hpp>
#include <Id/CubismIdManager.hpp>
#include <Motion/CubismMotionQueueEntry.hpp>
#include <LAppDefine.hpp>
#include "LAppPal_CalcOnly.hpp"
#include "Motion/CubismBreathUpdater.hpp"
#include "Motion/CubismLookUpdater.hpp"
#include "Motion/CubismExpressionUpdater.hpp"
#include "Motion/CubismEyeBlinkUpdater.hpp"
#include "Motion/CubismLipSyncUpdater.hpp"
#include "Motion/CubismPhysicsUpdater.hpp"
#include "Motion/CubismPoseUpdater.hpp"

using namespace Live2D::Cubism::Framework;
using namespace Live2D::Cubism::Framework::DefaultParameterId;

LAppModel_CalcOnly::LAppModel_CalcOnly()
    : LAppModel_Common()
    , _modelSetting(NULL)
    , _userTimeSeconds(0.0f)
    , _motionUpdated(false)
    , _breathUpdater(NULL)
    , _eyeBlinkUpdater(NULL)
    , _expressionUpdater(NULL)
    , _lookUpdater(NULL)
    , _physicsUpdater(NULL)
    , _lipSyncUpdater(NULL)
    , _poseUpdater(NULL)
    , _breathEnabled(true)
    , _eyeBlinkEnabled(true)
    , _expressionEnabled(true)
    , _lookEnabled(true)
    , _physicsEnabled(true)
    , _lipSyncEnabled(true)
    , _poseEnabled(true)
    , _useExternalLipSync(false)
    , _externalLipSyncValue(0.0f)
{
    if (LAppDefine::MocConsistencyValidationEnable)
    {
        _mocConsistency = true;
    }
    if (LAppDefine::MotionConsistencyValidationEnable)
    {
        _motionConsistency = true;
    }

    if (LAppDefine::DebugLogEnable)
    {
        _debugMode = true;
    }

    _idParamAngleX = CubismFramework::GetIdManager()->GetId(ParamAngleX);
    _idParamAngleY = CubismFramework::GetIdManager()->GetId(ParamAngleY);
    _idParamAngleZ = CubismFramework::GetIdManager()->GetId(ParamAngleZ);
    _idParamBodyAngleX = CubismFramework::GetIdManager()->GetId(ParamBodyAngleX);
    _idParamEyeBallX = CubismFramework::GetIdManager()->GetId(ParamEyeBallX);
    _idParamEyeBallY = CubismFramework::GetIdManager()->GetId(ParamEyeBallY);
}

LAppModel_CalcOnly::~LAppModel_CalcOnly()
{
    // Clean up manually managed updaters
    if (_breathUpdater) { CSM_DELETE(_breathUpdater); _breathUpdater = NULL; }
    if (_eyeBlinkUpdater) { CSM_DELETE(_eyeBlinkUpdater); _eyeBlinkUpdater = NULL; }
    if (_expressionUpdater) { CSM_DELETE(_expressionUpdater); _expressionUpdater = NULL; }
    if (_lookUpdater) { CSM_DELETE(_lookUpdater); _lookUpdater = NULL; }
    if (_physicsUpdater) { CSM_DELETE(_physicsUpdater); _physicsUpdater = NULL; }
    if (_lipSyncUpdater) { CSM_DELETE(_lipSyncUpdater); _lipSyncUpdater = NULL; }
    if (_poseUpdater) { CSM_DELETE(_poseUpdater); _poseUpdater = NULL; }

    ReleaseMotions();
    ReleaseExpressions();

    if (_modelSetting != NULL)
    {
        for (csmInt32 i = 0; i < _modelSetting->GetMotionGroupCount(); i++)
        {
            const csmChar* group = _modelSetting->GetMotionGroupName(i);
            ReleaseMotionGroup(group);
        }
        delete(_modelSetting);
        _modelSetting = NULL;
    }
}

void LAppModel_CalcOnly::LoadAssets(const csmChar* dir, const csmChar* fileName)
{
    _modelHomeDir = dir;

    if (_debugMode)
    {
        LAppPal_CalcOnly::PrintLogLn("[APP]load model setting: %s", fileName);
    }

    csmSizeInt size;
    const csmString path = csmString(dir) + fileName;

    csmByte* buffer = CreateBuffer(path.GetRawString(), &size);
    if (buffer == NULL)
    {
        LAppPal_CalcOnly::PrintLogLn("[APP]ERROR: Failed to read model3.json: %s", path.GetRawString());
        _model = NULL;
        return;
    }
    ICubismModelSetting* setting = new CubismModelSettingJson(buffer, size);
    DeleteBuffer(buffer, path.GetRawString());

    SetupModel(setting);

    if (_model == NULL)
    {
        LAppPal_CalcOnly::PrintLogLn("Failed to LoadAssets().");
        return;
    }

    // NOTE: Does NOT call CreateRenderer() or SetupTextures()
    // Rendering is handled on the Haxe side via drawable interface
}

void LAppModel_CalcOnly::SetupModel(ICubismModelSetting* setting)
{
    _updating = true;
    _initialized = false;

    _modelSetting = setting;

    csmByte* buffer;
    csmSizeInt size;

    // Cubism Model
    if (strcmp(_modelSetting->GetModelFileName(), "") != 0)
    {
        csmString path = _modelSetting->GetModelFileName();
        path = _modelHomeDir + path;

        if (_debugMode)
        {
            LAppPal_CalcOnly::PrintLogLn("[APP]create model: %s", setting->GetModelFileName());
        }

        buffer = CreateBuffer(path.GetRawString(), &size);
        LoadModel(buffer, size, _mocConsistency);
        DeleteBuffer(buffer, path.GetRawString());
    }

    // Expression
    if (_modelSetting->GetExpressionCount() > 0)
    {
        const csmInt32 count = _modelSetting->GetExpressionCount();
        for (csmInt32 i = 0; i < count; i++)
        {
            csmString name = _modelSetting->GetExpressionName(i);
            csmString path = _modelSetting->GetExpressionFileName(i);
            path = _modelHomeDir + path;

            buffer = CreateBuffer(path.GetRawString(), &size);
            ACubismMotion* motion = LoadExpression(buffer, size, name.GetRawString());

            if (motion)
            {
                if (_expressions[name] != NULL)
                {
                    ACubismMotion::Delete(_expressions[name]);
                    _expressions[name] = NULL;
                }
                _expressions[name] = motion;
            }

            DeleteBuffer(buffer, path.GetRawString());
        }
        CubismExpressionUpdater* expression = CSM_NEW CubismExpressionUpdater(*_expressionManager);
        _expressionUpdater = expression;
    }

    // Physics
    if (strcmp(_modelSetting->GetPhysicsFileName(), "") != 0)
    {
        csmString path = _modelSetting->GetPhysicsFileName();
        path = _modelHomeDir + path;

        buffer = CreateBuffer(path.GetRawString(), &size);
        LoadPhysics(buffer, size);
        if (_physics != nullptr)
        {
            CubismPhysicsUpdater* physics = CSM_NEW CubismPhysicsUpdater(*_physics);
            _physicsUpdater = physics;
        }
        DeleteBuffer(buffer, path.GetRawString());
    }

    // Pose
    if (strcmp(_modelSetting->GetPoseFileName(), "") != 0)
    {
        csmString path = _modelSetting->GetPoseFileName();
        path = _modelHomeDir + path;

        buffer = CreateBuffer(path.GetRawString(), &size);
        LoadPose(buffer, size);
        if (_pose != nullptr)
        {
            CubismPoseUpdater* pose = CSM_NEW CubismPoseUpdater(*_pose);
            _poseUpdater = pose;
        }
        DeleteBuffer(buffer, path.GetRawString());
    }

    // EyeBlink
    {
        if (_modelSetting->GetEyeBlinkParameterCount() > 0)
        {
            _eyeBlink = CubismEyeBlink::Create(_modelSetting);

            CubismEyeBlinkUpdater* eyeBlink = CSM_NEW CubismEyeBlinkUpdater(_motionUpdated, *_eyeBlink);
            _eyeBlinkUpdater = eyeBlink;
        }
    }

    // Breath
    {
        _breath = CubismBreath::Create();

        csmVector<CubismBreath::BreathParameterData> breathParameters;

        breathParameters.PushBack(CubismBreath::BreathParameterData(_idParamAngleX, 0.0f, 15.0f, 6.5345f, 0.5f));
        breathParameters.PushBack(CubismBreath::BreathParameterData(_idParamAngleY, 0.0f, 8.0f, 3.5345f, 0.5f));
        breathParameters.PushBack(CubismBreath::BreathParameterData(_idParamAngleZ, 0.0f, 10.0f, 5.5345f, 0.5f));
        breathParameters.PushBack(CubismBreath::BreathParameterData(_idParamBodyAngleX, 0.0f, 4.0f, 15.5345f, 0.5f));
        breathParameters.PushBack(CubismBreath::BreathParameterData(CubismFramework::GetIdManager()->GetId(ParamBreath), 0.5f, 0.5f, 3.2345f, 0.5f));

        _breath->SetParameters(breathParameters);

        CubismBreathUpdater* breath = CSM_NEW CubismBreathUpdater(*_breath);
        _breathUpdater = breath;
    }

    // UserData
    if (strcmp(_modelSetting->GetUserDataFile(), "") != 0)
    {
        csmString path = _modelSetting->GetUserDataFile();
        path = _modelHomeDir + path;
        buffer = CreateBuffer(path.GetRawString(), &size);
        LoadUserData(buffer, size);
        DeleteBuffer(buffer, path.GetRawString());
    }

    // EyeBlinkIds
    {
        csmInt32 eyeBlinkIdCount = _modelSetting->GetEyeBlinkParameterCount();
        for (csmInt32 i = 0; i < eyeBlinkIdCount; ++i)
        {
            _eyeBlinkIds.PushBack(_modelSetting->GetEyeBlinkParameterId(i));
        }
    }

    // LipSyncIds
    {
        csmInt32 lipSyncIdCount = _modelSetting->GetLipSyncParameterCount();
        for (csmInt32 i = 0; i < lipSyncIdCount; ++i)
        {
            _lipSyncIds.PushBack(_modelSetting->GetLipSyncParameterId(i));
        }
        CubismLipSyncUpdater* lipSync = CSM_NEW CubismLipSyncUpdater(_lipSyncIds, _wavFileHandler);
        _lipSyncUpdater = lipSync;
    }

    // Look
    {
        _look = CubismLook::Create();

        csmVector<CubismLook::LookParameterData> lookParameters;

        lookParameters.PushBack(CubismLook::LookParameterData(_idParamAngleX, 30.0f));
        lookParameters.PushBack(CubismLook::LookParameterData(_idParamAngleY, 0.0f, 30.0f));
        lookParameters.PushBack(CubismLook::LookParameterData(_idParamAngleZ, 0.0f, 0.0f, -30.0f));
        lookParameters.PushBack(CubismLook::LookParameterData(_idParamBodyAngleX, 10.0f));
        lookParameters.PushBack(CubismLook::LookParameterData(_idParamEyeBallX, 1.0f));
        lookParameters.PushBack(CubismLook::LookParameterData(_idParamEyeBallY, 0.0f, 1.0f));

        _look->SetParameters(lookParameters);

        CubismLookUpdater* look = CSM_NEW CubismLookUpdater(*_look, *_dragManager);
        _lookUpdater = look;
    }

    // Note: Not using _updateScheduler.SortUpdatableList() since we manage updaters manually

    if (_modelSetting == NULL || _modelMatrix == NULL)
    {
        LAppPal_CalcOnly::PrintLogLn("Failed to SetupModel().");
        return;
    }

    // Layout
    csmMap<csmString, csmFloat32> layout;
    _modelSetting->GetLayoutMap(layout);
    _modelMatrix->SetupFromLayout(layout);

    _model->SaveParameters();

    for (csmInt32 i = 0; i < _modelSetting->GetMotionGroupCount(); i++)
    {
        const csmChar* group = _modelSetting->GetMotionGroupName(i);
        PreloadMotionGroup(group);
    }

    _motionManager->StopAllMotions();

    _updating = false;
    _initialized = true;
}

void LAppModel_CalcOnly::PreloadMotionGroup(const csmChar* group)
{
    const csmInt32 count = _modelSetting->GetMotionCount(group);

    for (csmInt32 i = 0; i < count; i++)
    {
        csmString name = Utils::CubismString::GetFormatedString("%s_%d", group, i);
        csmString path = _modelSetting->GetMotionFileName(group, i);
        path = _modelHomeDir + path;

        if (_debugMode)
        {
            LAppPal_CalcOnly::PrintLogLn("[APP]load motion: %s => [%s_%d] ", path.GetRawString(), group, i);
        }

        csmByte* buffer;
        csmSizeInt size;
        buffer = CreateBuffer(path.GetRawString(), &size);
        CubismMotion* tmpMotion = static_cast<CubismMotion*>(LoadMotion(buffer, size, name.GetRawString(), NULL, NULL, _modelSetting, group, i, _motionConsistency));

        if (tmpMotion)
        {
            tmpMotion->SetEffectIds(_eyeBlinkIds, _lipSyncIds);

            if (_motions[name] != NULL)
            {
                ACubismMotion::Delete(_motions[name]);
            }
            _motions[name] = tmpMotion;
        }

        DeleteBuffer(buffer, path.GetRawString());
    }
}

void LAppModel_CalcOnly::ReleaseMotionGroup(const csmChar* group) const
{
    const csmInt32 count = _modelSetting->GetMotionCount(group);
    for (csmInt32 i = 0; i < count; i++)
    {
        csmString voice = _modelSetting->GetMotionSoundFileName(group, i);
        if (strcmp(voice.GetRawString(), "") != 0)
        {
            csmString path = voice;
            path = _modelHomeDir + path;
        }
    }
}

void LAppModel_CalcOnly::ReleaseMotions()
{
    for (csmMap<csmString, ACubismMotion*>::const_iterator iter = _motions.Begin(); iter != _motions.End(); ++iter)
    {
        ACubismMotion::Delete(iter->Second);
    }

    _motions.Clear();
}

void LAppModel_CalcOnly::ReleaseExpressions()
{
    for (csmMap<csmString, ACubismMotion*>::const_iterator iter = _expressions.Begin(); iter != _expressions.End(); ++iter)
    {
        ACubismMotion::Delete(iter->Second);
    }

    _expressions.Clear();
}

void LAppModel_CalcOnly::Update()
{
    const csmFloat32 deltaTimeSeconds = LAppPal_CalcOnly::GetDeltaTime();
    _userTimeSeconds += deltaTimeSeconds;

    _motionUpdated = false;

    _model->LoadParameters();
    if (_motionManager->IsFinished())
    {
        StartRandomMotion(LAppDefine::MotionGroupIdle, LAppDefine::PriorityIdle);
    }
    else
    {
        _motionUpdated = _motionManager->UpdateMotion(_model, deltaTimeSeconds);
    }
    _model->SaveParameters();

    _opacity = _model->GetModelOpacity();

    // Manual updater calls with enabled checks (same order as CubismUpdateOrder)
    if (_eyeBlinkEnabled && _eyeBlinkUpdater)
        _eyeBlinkUpdater->OnLateUpdate(_model, deltaTimeSeconds);
    if (_expressionEnabled && _expressionUpdater)
        _expressionUpdater->OnLateUpdate(_model, deltaTimeSeconds);
    if (_lookEnabled && _lookUpdater)
        _lookUpdater->OnLateUpdate(_model, deltaTimeSeconds);
    if (_breathEnabled && _breathUpdater)
        _breathUpdater->OnLateUpdate(_model, deltaTimeSeconds);
    if (_physicsEnabled && _physicsUpdater)
        _physicsUpdater->OnLateUpdate(_model, deltaTimeSeconds);
    if (_lipSyncEnabled && _lipSyncUpdater)
    {
        if (_useExternalLipSync)
        {
            // Directly set lip sync parameter value from external source
            for (csmUint32 i = 0; i < _lipSyncIds.GetSize(); ++i)
            {
                _model->AddParameterValue(_lipSyncIds[i], _externalLipSyncValue, 0.8f);
            }
        }
        else
        {
            _lipSyncUpdater->OnLateUpdate(_model, deltaTimeSeconds);
        }
    }
    if (_poseEnabled && _poseUpdater)
        _poseUpdater->OnLateUpdate(_model, deltaTimeSeconds);

    _model->Update();
}

CubismMotionQueueEntryHandle LAppModel_CalcOnly::StartMotion(const csmChar* group, csmInt32 no, csmInt32 priority, 
    ACubismMotion::FinishedMotionCallback onFinishedMotionHandler, ACubismMotion::BeganMotionCallback onBeganMotionHandler)
{
    if (priority == LAppDefine::PriorityForce)
    {
        _motionManager->SetReservePriority(priority);
    }
    else if (!_motionManager->ReserveMotion(priority))
    {
        if (_debugMode)
        {
            LAppPal_CalcOnly::PrintLogLn("[APP]can't start motion.");
        }
        return InvalidMotionQueueEntryHandleValue;
    }

    const csmString fileName = _modelSetting->GetMotionFileName(group, no);

    csmString name = Utils::CubismString::GetFormatedString("%s_%d", group, no);
    CubismMotion* motion = static_cast<CubismMotion*>(_motions[name.GetRawString()]);
    csmBool autoDelete = false;

    if (motion == NULL)
    {
        csmString path = fileName;
        path = _modelHomeDir + path;

        csmByte* buffer;
        csmSizeInt size;
        buffer = CreateBuffer(path.GetRawString(), &size);
        motion = static_cast<CubismMotion*>(LoadMotion(buffer, size, NULL, onFinishedMotionHandler, onBeganMotionHandler, _modelSetting, group, no, _motionConsistency));

        if (motion)
        {
            motion->SetEffectIds(_eyeBlinkIds, _lipSyncIds);
            autoDelete = true;
        }
        else
        {
            CubismLogError("Can't start motion %s .", path.GetRawString());
            _motionManager->SetReservePriority(LAppDefine::PriorityNone);
            DeleteBuffer(buffer, path.GetRawString());
            return InvalidMotionQueueEntryHandleValue;
        }

        DeleteBuffer(buffer, path.GetRawString());
    }
    else
    {
        motion->SetBeganMotionHandler(onBeganMotionHandler);
        motion->SetFinishedMotionHandler(onFinishedMotionHandler);
    }

    csmString voice = _modelSetting->GetMotionSoundFileName(group, no);
    if (strcmp(voice.GetRawString(), "") != 0)
    {
        csmString path = voice;
        path = _modelHomeDir + path;
        _wavFileHandler.Start(path);
    }

    if (_debugMode)
    {
        LAppPal_CalcOnly::PrintLogLn("[APP]start motion: [%s_%d]", group, no);
    }
    return _motionManager->StartMotionPriority(motion, autoDelete, priority);
}

CubismMotionQueueEntryHandle LAppModel_CalcOnly::StartRandomMotion(const csmChar* group, csmInt32 priority,
    ACubismMotion::FinishedMotionCallback onFinishedMotionHandler, ACubismMotion::BeganMotionCallback onBeganMotionHandler)
{
    if (_modelSetting->GetMotionCount(group) == 0)
    {
        return InvalidMotionQueueEntryHandleValue;
    }

    csmInt32 no = rand() % _modelSetting->GetMotionCount(group);

    return StartMotion(group, no, priority, onFinishedMotionHandler, onBeganMotionHandler);
}

csmBool LAppModel_CalcOnly::HitTest(const csmChar* hitAreaName, csmFloat32 x, csmFloat32 y)
{
    if (_opacity < 1)
    {
        return false;
    }
    const csmInt32 count = _modelSetting->GetHitAreasCount();
    for (csmInt32 i = 0; i < count; i++)
    {
        if (strcmp(_modelSetting->GetHitAreaName(i), hitAreaName) == 0)
        {
            const CubismIdHandle drawID = _modelSetting->GetHitAreaId(i);
            return IsHit(drawID, x, y);
        }
    }
    return false;
}

csmBool LAppModel_CalcOnly::IsMotionFinished(CubismMotionQueueEntryHandle motionHandle)
{
    return _motionManager->IsFinished(motionHandle);
}

void LAppModel_CalcOnly::SetExpression(const csmChar* expressionID)
{
    ACubismMotion* motion = _expressions[expressionID];
    if (_debugMode)
    {
        LAppPal_CalcOnly::PrintLogLn("[APP]expression: [%s]", expressionID);
    }

    if (motion != NULL)
    {
        _expressionManager->StartMotion(motion, false);
    }
    else if (_debugMode)
    {
        LAppPal_CalcOnly::PrintLogLn("[APP]expression[%s] is null ", expressionID);
    }
}

void LAppModel_CalcOnly::SetRandomExpression()
{
    if (_expressions.GetSize() == 0)
    {
        return;
    }

    csmInt32 no = rand() % _expressions.GetSize();
    csmMap<csmString, ACubismMotion*>::const_iterator map_ite;
    csmInt32 i = 0;
    for (map_ite = _expressions.Begin(); map_ite != _expressions.End(); map_ite++)
    {
        if (i == no)
        {
            csmString name = (*map_ite).First;
            SetExpression(name.GetRawString());
            return;
        }
        i++;
    }
}

csmBool LAppModel_CalcOnly::HasMocConsistencyFromFile(const csmChar* mocFileName)
{
    CSM_ASSERT(strcmp(mocFileName, ""));

    csmByte* buffer;
    csmSizeInt size;

    csmString path = mocFileName;
    path = _modelHomeDir + path;

    buffer = CreateBuffer(path.GetRawString(), &size);

    csmBool consistency = CubismMoc::HasMocConsistencyFromUnrevivedMoc(buffer, size);

    DeleteBuffer(buffer);

    return consistency;
}

csmInt32 LAppModel_CalcOnly::GetTextureCount()
{
    if (_modelSetting == NULL)
    {
        return 0;
    }
    return _modelSetting->GetTextureCount();
}

void LAppModel_CalcOnly::GetTexturePath(csmInt32 textureIndex, csmChar* outBuf, csmInt32 bufLen)
{
    if (_modelSetting == NULL)
    {
        outBuf[0] = '\0';
        return;
    }
    
    const csmChar* textureFileName = _modelSetting->GetTextureFileName(textureIndex);
    if (textureFileName == NULL || strcmp(textureFileName, "") == 0)
    {
        outBuf[0] = '\0';
        return;
    }

    strncpy_s(outBuf, bufLen, textureFileName, bufLen - 1);
    outBuf[bufLen - 1] = '\0';
}

// ===== Framework Behavior Control =====

void LAppModel_CalcOnly::SetBreathEnabled(csmBool enabled) { _breathEnabled = enabled; }
void LAppModel_CalcOnly::SetEyeBlinkEnabled(csmBool enabled) { _eyeBlinkEnabled = enabled; }
void LAppModel_CalcOnly::SetExpressionEnabled(csmBool enabled) { _expressionEnabled = enabled; }
void LAppModel_CalcOnly::SetLookEnabled(csmBool enabled) { _lookEnabled = enabled; }
void LAppModel_CalcOnly::SetPhysicsEnabled(csmBool enabled) { _physicsEnabled = enabled; }
void LAppModel_CalcOnly::SetLipSyncEnabled(csmBool enabled) { _lipSyncEnabled = enabled; }
void LAppModel_CalcOnly::SetPoseEnabled(csmBool enabled) { _poseEnabled = enabled; }

void LAppModel_CalcOnly::SetLipSyncValue(csmFloat32 value)
{
    if (value < 0.0f)
    {
        _useExternalLipSync = false;
        _externalLipSyncValue = 0.0f;
    }
    else
    {
        _useExternalLipSync = true;
        _externalLipSyncValue = (value > 1.0f) ? 1.0f : value;
    }
}

csmBool LAppModel_CalcOnly::IsBreathEnabled() const { return _breathEnabled; }
csmBool LAppModel_CalcOnly::IsEyeBlinkEnabled() const { return _eyeBlinkEnabled; }
csmBool LAppModel_CalcOnly::IsExpressionEnabled() const { return _expressionEnabled; }
csmBool LAppModel_CalcOnly::IsLookEnabled() const { return _lookEnabled; }
csmBool LAppModel_CalcOnly::IsPhysicsEnabled() const { return _physicsEnabled; }
csmBool LAppModel_CalcOnly::IsLipSyncEnabled() const { return _lipSyncEnabled; }
csmBool LAppModel_CalcOnly::IsPoseEnabled() const { return _poseEnabled; }
