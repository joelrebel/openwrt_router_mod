LuaQ                    A@  @    A�  � E   ��  \� �   � � AA A� � @ �@�� � AA A� � @ �@�� � AA A � @ �@�� � AA AA � @ �@��   � @ ��E� �C ˂CA� ܂����� \� ��� �� �BDς��� ɀ!�  �� AA �� �� � �  �  AF�F�� E� K��A   E� �� \ \�  G� E� K��� B E� �� \ \�    �E� K��� 	 E� �B	 \ \�  G� E� K��� �	 E� ��	 \ \�  G�	 E�	 �     I��E� K��� B
 E� ��
 \ \�  GA
 EA
 �A     I��E� K�� �
 E� �B \� �� �� � \�  G�
 E�
 I̗E�
 I̘E�
 I�L�E�
 K��� B E� �� \ \�  IΛE�
 K��Ł � E� �� \� �� � � \�  GA E� � \���B �BO �FC�Z   �J ���C�bC PC��B a�  @�E�
 K��Ł � E� �B	 \ \A  E�
 K��Ł  E� �� \� �� �B � \A  E�
 K��Ł � E� �� \� �� � C A�
 � \A  E� K�� � A� �� � � \�  G� E� I̗E� I̘E� I�L�E� K��� B E� �� \ \�  IΛE� K��Ł � E� �� \� �� � � \�  GA E� � \���B �BO �FC�Z   �J ���C�bC PC��B a�  @�E� ^  � I      require    luci.tools.webadmin 	   nixio.fs    nixio.util    consume    glob 	   /dev/sd* 	   /dev/hd* 
   /dev/scd* 
   /dev/mmc*    ipairs 	   tonumber 	   readfile    /sys/class/block/%s/size    sub 	      math    floor 	      m    Map    fstab 
   translate 
   a_s_fstab    luci    sys    mounts    v    section    Table    a_s_fstab_active    option    DummyValue    fs    filesystem    mp    mountpoint    a_s_fstab_mountpoint    avail    a_s_fstab_avail 	   cfgvalue    used    a_s_fstab_used    mount    TypedSection    a_s_fstab_mountpoints    a_s_fstab_mountpoints1 
   anonymous 
   addremove 	   template    cbi/tblsection    Flag    enabled    enable    rmempty     dev    Value    device    a_s_fstab_device1    value    %s (%s MB)    target    fstype    a_s_fstab_fs1    options    translatef    manpage    siehe '%s' manpage    swap    SWAP    a_s_fstab_swap1        +   1        �   �@@��@��@�    A AA܀ �@    ��� ����� �    A@�@�@E �  �A �AB\� ZA    �A� N��� � �   � 
      luci    tools 	   webadmin    byte_format 	   tonumber 
   available 	    	       /     blocks                     4   9       �   �@ � @�@    ��@  ��  �  AAA�AE� �  �A �B\� ZA    �AA N��� A� �@�   �       percent    0%     (    luci    tools 	   webadmin    byte_format 	   tonumber    used 	    	      )                             