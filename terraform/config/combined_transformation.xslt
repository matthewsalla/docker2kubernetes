<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  
  <xsl:output method="xml" indent="yes"/>
  
  <!-- Identity transform: copy everything by default -->
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- Add memoryBacking to the root domain element -->
  <xsl:template match="/domain">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
      <memoryBacking>
        <source type="memfd"/>
        <access mode="shared"/>
      </memoryBacking>
    </xsl:copy>
  </xsl:template>
  
  <!-- Change the disk driver type from raw to qcow2 for disks with target dev="vdb" -->
  <xsl:template match="disk[source/@file and target[@dev='vdb']]/driver[@type='raw']/@type">
    <xsl:attribute name="type">qcow2</xsl:attribute>
  </xsl:template>
  
</xsl:stylesheet>
