<AnimDB FragDef="Animations/Mannequin/ADB/jackFragmentIdstags.xml" TagDef="Animations/Mannequin/ADB/jacktags.xml">
 <FragmentList>
  <Idle>
   <Fragment BlendOutDuration="0.2" Tags="">
    <AnimLayer>
     <Blend ExitTime="0" StartTime="0" Duration="0.2" CurveType="0"/>
     <Animation name="jack_idle_bspace" flags="Loop"/>
    </AnimLayer>
   </Fragment>
  </Idle>
  <Moving>
   <Fragment BlendOutDuration="0.2" Tags="">
    <AnimLayer>
     <Blend ExitTime="0" StartTime="0" Duration="0.5" CurveType="0"/>
     <Animation name="jack_movement_combination" flags="Loop"/>
    </AnimLayer>
   </Fragment>
  </Moving>
  <Aiming>
   <Fragment BlendOutDuration="0.2" Tags="">
    <AnimLayer>
     <Blend ExitTime="0" StartTime="0" Duration="0.2" CurveType="0"/>
     <Animation name="jack_aim_all" flags="Loop" weight="0"/>
    </AnimLayer>
   </Fragment>
  </Aiming>
  <IdleTurn>
   <Fragment BlendOutDuration="0.2" Tags="">
    <AnimLayer>
     <Blend ExitTime="0" StartTime="0" Duration="0" CurveType="0"/>
     <Animation name="jack_idle_turn"/>
    </AnimLayer>
   </Fragment>
  </IdleTurn>
  <Idle2Move>
   <Fragment BlendOutDuration="0.2" Tags="">
    <AnimLayer>
     <Blend ExitTime="0" StartTime="0" Duration="0.2" CurveType="0"/>
     <Animation name="jack_idle2move"/>
    </AnimLayer>
   </Fragment>
  </Idle2Move>
  <Move2Idle>
   <Fragment BlendOutDuration="0.2" Tags="">
    <AnimLayer>
     <Blend ExitTime="0" StartTime="0" Duration="0.2" CurveType="0"/>
     <Animation name="jack_move2idle"/>
    </AnimLayer>
   </Fragment>
  </Move2Idle>
  <Shoot>
   <Fragment BlendOutDuration="0.2" Tags="">
    <AnimLayer>
     <Blend ExitTime="0" StartTime="0" Duration="0" CurveType="0"/>
     <Animation name="jack_shoot" speed="8" weight="0.75"/>
    </AnimLayer>
   </Fragment>
  </Shoot>
  <Hit>
   <Fragment BlendOutDuration="0.2" Tags="">
    <AnimLayer>
     <Blend ExitTime="0" StartTime="0" Duration="0" CurveType="0"/>
     <Animation name="jack_take_damage"/>
    </AnimLayer>
   </Fragment>
  </Hit>
  <Dead>
   <Fragment BlendOutDuration="0.2" Tags="" FragTags="DeathBack">
    <AnimLayer>
     <Blend ExitTime="0" StartTime="0" Duration="0.2" CurveType="0"/>
     <Animation name="enemy_death_fall_forward"/>
    </AnimLayer>
   </Fragment>
   <Fragment BlendOutDuration="0.2" Tags="" FragTags="DeathFront">
    <AnimLayer>
     <Blend ExitTime="0" StartTime="0" Duration="0.2" CurveType="0"/>
     <Animation name="enemy_death_fall_back"/>
    </AnimLayer>
   </Fragment>
  </Dead>
 </FragmentList>
</AnimDB>
