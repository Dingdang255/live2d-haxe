/**
 * Live2D Cubism SDK for Native - CalcOnly version
 * Simplified LAppModel implementation - parameter calculation only, no rendering
 * 
 * Copyright(c) Live2D Inc. All rights reserved.
 * Use of this source code is governed by the Live2D Open Software license.
 */

#pragma once

#include <CubismFramework.hpp>
#include <ICubismModelSetting.hpp>
#include <Type/csmRectF.hpp>
#include <LAppWavFileHandler_Common.hpp>
#include <LAppModel_Common.hpp>
#include <Motion/ICubismUpdater.hpp>
#include <Motion/CubismBreathUpdater.hpp>
#include <Motion/CubismEyeBlinkUpdater.hpp>
#include <Motion/CubismExpressionUpdater.hpp>
#include <Motion/CubismLookUpdater.hpp>
#include <Motion/CubismPhysicsUpdater.hpp>
#include <Motion/CubismLipSyncUpdater.hpp>
#include <Motion/CubismPoseUpdater.hpp>

/**
 * CalcOnly model class
 * Inherits LAppModel_Common, only implements parameter calculation logic
 * Does not include any renderer creation/binding code
 */
class LAppModel_CalcOnly : public LAppModel_Common
{
public:
    LAppModel_CalcOnly();
    virtual ~LAppModel_CalcOnly();

    /**
     * Generate model from directory and file path where model3.json is placed
     */
    void LoadAssets(const Csm::csmChar* dir, const Csm::csmChar* fileName);

    /**
     * Model update process. Determines drawing state from model parameters.
     */
    void Update();

    /**
     * Start playing the motion specified by argument
     */
    Csm::CubismMotionQueueEntryHandle StartMotion(const Csm::csmChar* group, Csm::csmInt32 no, Csm::csmInt32 priority, 
        Csm::ACubismMotion::FinishedMotionCallback onFinishedMotionHandler = NULL, 
        Csm::ACubismMotion::BeganMotionCallback onBeganMotionHandler = NULL);

    /**
     * Start playing a randomly selected motion
     */
    Csm::CubismMotionQueueEntryHandle StartRandomMotion(const Csm::csmChar* group, Csm::csmInt32 priority,
        Csm::ACubismMotion::FinishedMotionCallback onFinishedMotionHandler = NULL,
        Csm::ACubismMotion::BeganMotionCallback onBeganMotionHandler = NULL);

    /**
     * Start playing a motion from an arbitrary file path.
     * Unlike StartMotion, this does NOT require the motion to be registered
     * in model3.json's FileReferences.Motions. The path can be absolute
     * or relative (resolved relative to the model's home directory if
     * not absolute).
     *
     * This is used for VTuber-style models where motions are standalone
     * .motion3.json files referenced from .vtube.json Hotkeys.
     */
    Csm::CubismMotionQueueEntryHandle StartMotionFile(const Csm::csmChar* path, Csm::csmInt32 priority,
        Csm::ACubismMotion::FinishedMotionCallback onFinishedMotionHandler = NULL,
        Csm::ACubismMotion::BeganMotionCallback onBeganMotionHandler = NULL);

    /**
     * Set the expression motion specified by argument
     */
    void SetExpression(const Csm::csmChar* expressionID);

    /**
     * Set a randomly selected expression motion
     */
    void SetRandomExpression();

    /**
     * Hit test
     */
    virtual Csm::csmBool HitTest(const Csm::csmChar* hitAreaName, Csm::csmFloat32 x, Csm::csmFloat32 y);

    /**
     * Check if motion is finished
     */
    Csm::csmBool IsMotionFinished(Csm::CubismMotionQueueEntryHandle motionHandle);

    /**
     * Get texture count
     */
    Csm::csmInt32 GetTextureCount();

    /**
     * Get texture path
     */
    void GetTexturePath(Csm::csmInt32 textureIndex, Csm::csmChar* outBuf, Csm::csmInt32 bufLen);

    /**
     * Override to capture motion UserData events into global queue for Haxe polling.
     */
    virtual void MotionEventFired(const Csm::csmString& eventValue) override;

    /**
     * Expose pose pointer for ResetPose C API.
     */
    Csm::CubismPose* GetPose() const { return _pose; }

    /**
     * Immediately stop all motions in the native queue without fadeout.
     * Used when force-switching to idle to prevent stale parameter values.
     */
    void StopAllNativeMotions() { _motionManager->StopAllMotions(); }

    // ===== Physics runtime tuning (wraps CubismPhysics SDK API) =====
    // Exposes SetOptions/GetOptions/Reset/Stabilization from CubismPhysics
    // so the Haxe layer can adjust gravity/wind at runtime and reset/stabilize
    // the pendulum simulation without reloading the model.
    void SetPhysicsOptions(Csm::csmFloat32 gravityX, Csm::csmFloat32 gravityY,
                           Csm::csmFloat32 windX, Csm::csmFloat32 windY);
    void GetPhysicsOptions(Csm::csmFloat32* outGravityX, Csm::csmFloat32* outGravityY,
                           Csm::csmFloat32* outWindX, Csm::csmFloat32* outWindY) const;
    void ResetPhysics();
    void StabilizePhysics();

protected:
    /**
     * Generate model from model3.json
     */
    void SetupModel(Csm::ICubismModelSetting* setting);

    /**
     * Load motion data by group name
     */
    void PreloadMotionGroup(const Csm::csmChar* group);

    /**
     * Release motion data by group name
     */
    void ReleaseMotionGroup(const Csm::csmChar* group) const;

    /**
     * Release all motion data
     */
    void ReleaseMotions();

    /**
     * Release all expression data
     */
    void ReleaseExpressions();

private:
    Csm::ICubismModelSetting* _modelSetting;
    Csm::csmString _modelHomeDir;
    Csm::csmFloat32 _userTimeSeconds;
    Csm::csmVector<Csm::CubismIdHandle> _eyeBlinkIds;
    Csm::csmVector<Csm::CubismIdHandle> _lipSyncIds;
    Csm::csmMap<Csm::csmString, Csm::ACubismMotion*> _motions;
    Csm::csmMap<Csm::csmString, Csm::ACubismMotion*> _expressions;
    Csm::csmVector<Csm::csmRectF> _hitArea;
    Csm::csmVector<Csm::csmRectF> _userArea;
    const Csm::CubismId* _idParamAngleX;
    const Csm::CubismId* _idParamAngleY;
    const Csm::CubismId* _idParamAngleZ;
    const Csm::CubismId* _idParamBodyAngleX;
    const Csm::CubismId* _idParamEyeBallX;
    const Csm::CubismId* _idParamEyeBallY;
    Csm::csmBool _motionUpdated;

    // Framework behavior updaters (managed manually, not through _updateScheduler)
    Csm::CubismBreathUpdater* _breathUpdater;
    Csm::CubismEyeBlinkUpdater* _eyeBlinkUpdater;
    Csm::CubismExpressionUpdater* _expressionUpdater;
    Csm::CubismLookUpdater* _lookUpdater;
    Csm::CubismPhysicsUpdater* _physicsUpdater;
    Csm::CubismLipSyncUpdater* _lipSyncUpdater;
    Csm::CubismPoseUpdater* _poseUpdater;

    // Enabled flags for each module (default: all true)
    Csm::csmBool _breathEnabled;
    Csm::csmBool _eyeBlinkEnabled;
    Csm::csmBool _expressionEnabled;
    Csm::csmBool _lookEnabled;
    Csm::csmBool _physicsEnabled;
    Csm::csmBool _lipSyncEnabled;
    Csm::csmBool _poseEnabled;

    // External lip sync (when true, uses _externalLipSyncValue instead of wav file handler)
    Csm::csmBool _useExternalLipSync;
    Csm::csmFloat32 _externalLipSyncValue;

    LAppWavFileHandler_Common _wavFileHandler;

public:
    // Framework behavior control
    void SetBreathEnabled(Csm::csmBool enabled);
    void SetEyeBlinkEnabled(Csm::csmBool enabled);
    void SetExpressionEnabled(Csm::csmBool enabled);
    void SetLookEnabled(Csm::csmBool enabled);
    void SetPhysicsEnabled(Csm::csmBool enabled);
    void SetLipSyncEnabled(Csm::csmBool enabled);
    void SetPoseEnabled(Csm::csmBool enabled);

    // External lip sync value (0~1, set <0 to revert to wav file handler)
    void SetLipSyncValue(Csm::csmFloat32 value);
};
