<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" indent="yes"/>

  <!-- Match the root <domain> node -->
  <xsl:template match="/domain">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
      <!-- Add memoryBacking section inside <domain> -->
      <memoryBacking>
        <source type='memfd'/>
        <access mode='shared'/>
      </memoryBacking>
    </xsl:copy>
  </xsl:template>

  <!-- Identity transform (preserve all other XML content) -->
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>
