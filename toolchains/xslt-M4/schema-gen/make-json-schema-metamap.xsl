<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math" exclude-result-prefixes="xs math"
    version="3.0" xmlns="http://www.w3.org/2005/xpath-functions"
    xpath-default-namespace="http://csrc.nist.gov/ns/oscal/metaschema/1.0" expand-text="true">

<!-- Purpose: Produce an XPath-JSON document representing JSON Schema declarations from Metaschema source data.
     The results are conformant to the rules for the XPath 3.1 definition of an XML format capable of being cast
     (using the xml-to-json() function) into JSON. -->
    
<!-- Note: this XSLT will only be used on its own for development and debugging.
     It is however imported by `produce-json-converter.xsl` and possibly other stylesheets. -->
    
    <xsl:strip-space elements="METASCHEMA define-assembly define-field model"/>
    
    <xsl:output indent="yes" method="xml"/>
    
    <xsl:template match="/" priority="2">
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:variable name="home" select="/"/>
    
    <xsl:variable name="string-value-label">STRVALUE</xsl:variable>
    <xsl:variable name="markdown-value-label">RICHTEXT</xsl:variable>
    <xsl:variable name="markdown-multiline-label">PROSE</xsl:variable>
    
    <xsl:key name="assembly-definition-by-name" match="METASCHEMA/define-assembly" use="@_key-name"/>
    <xsl:key name="field-definition-by-name"    match="METASCHEMA/define-field"    use="@_key-name"/>
    <xsl:key name="flag-definition-by-name"     match="METASCHEMA/define-flag"     use="@_key-name"/>
    
    <!-- Produces composed metaschema (imports resolved) -->
    <!--<xsl:import href="../lib/metaschema-compose.xsl"/>-->
    <xsl:variable name="composed-metaschema" select="/"/>
    
    <!-- bypasses composition to operate on the 'raw' metaschema for debugging -->
    <!--<xsl:template mode="debug"  match="/METASCHEMA">
        <xsl:apply-templates select="*"/>
    </xsl:template>-->

   
    <xsl:template match="/METASCHEMA" expand-text="true">
        <map>
            <string key="$schema">http://json-schema.org/draft-07/schema#</string>
            <string key="$id">{ json-base-uri }/{ schema-version }/{ short-name }-schema.json</string>
            <xsl:for-each select="schema-name">
                <string key="$comment">{ . }: JSON Schema</string>
            </xsl:for-each>
            
            <!--<xsl:apply-templates select="schema-version"/>-->
            <string key="type">object</string>
            <map key="definitions">
                <xsl:apply-templates select="define-assembly | define-field"/>
            </map>           
            <xsl:apply-templates select="." mode="require-a-root"/>
        </map>
    </xsl:template>
    
    <xsl:template match="/METASCHEMA" mode="require-a-root">
        <xsl:apply-templates select="define-assembly[exists(root-name)]" mode="root-requirement"/>
        <boolean key="additionalProperties">false</boolean>
        <number key="maxProperties">1</number>
    </xsl:template>
    
   
    <xsl:template priority="2" match="/METASCHEMA[count(define-assembly/root-name) > 1]" mode="require-a-root">
        <array key="oneOf">
            <xsl:for-each select="define-assembly[exists(root-name)]">
                <map>
                    <xsl:apply-templates select="." mode="root-requirement"/>
                    <boolean key="additionalProperties">false</boolean>
                    <number key="maxProperties">1</number>
                </map>
            </xsl:for-each>
        </array>
    </xsl:template>
    
    <xsl:template match="define-assembly" mode="root-requirement">
        <map key="properties">
            <map key="{root-name}">
                <xsl:apply-templates select="." mode="make-ref"/>
            </map>
        </map>
        <array key="required">
            <string>{ root-name }</string>
        </array>
    </xsl:template>

    <xsl:template match="METASCHEMA/schema-name"/>
    <xsl:template match="METASCHEMA/short-name"/>
    <xsl:template match="METASCHEMA/remarks"/>
    <xsl:template match="METASCHEMA/namespace"/>
    
    <xsl:template match="METASCHEMA/schema-version" expand-text="true">
        <!--property not permitted by JSON Schema v7 -->
        <!--<string key="version">{ . }</string>-->
    </xsl:template>
    
    <!-- Flag declarations are all handled at the point of invocation -->
    <xsl:template match="define-flag"/>
    
    <xsl:template name="give-id">
        <!-- Only marking top-level not inline definitions -->
        <xsl:if test="exists(parent::METASCHEMA)">
            <string key="$id">
                <xsl:apply-templates mode="make-definition-id" select="."/>
            </string>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="*" mode="make-ref">
        <string key="$ref">
            <xsl:apply-templates mode="make-definition-id" select="."/>
        </string>
    </xsl:template>
    
    <xsl:template match="*" mode="make-definition-id">
        <xsl:text expand-text="true">#{ substring(replace(@_metaschema-json-id,'/','_'),2) }</xsl:text>
    </xsl:template>

    <xsl:template priority="100" match="METASCHEMA/define-assembly">
        <map key="{ $composed-metaschema/*/short-name }-{ @_key-name }">
            <!--<string key="xslt-lineno">123</string>-->
            <xsl:next-match/>
        </map>
    </xsl:template>
    
    <xsl:template priority="100" match="METASCHEMA/define-field">
        <map key="{ $composed-metaschema/*/short-name }-{ @_key-name }">
            <xsl:next-match/>
        </map>
    </xsl:template>
    
    <xsl:template match="define-assembly">
        <xsl:apply-templates select="formal-name, description"/>
        <xsl:call-template name="give-id"/>
        <string key="type">object</string>
        <xsl:where-populated>
            <map key="properties">
                <xsl:apply-templates select="." mode="properties"/>
            </map>
        </xsl:where-populated>
        <xsl:call-template name="require-or-allow"/>
    </xsl:template>
    
    <xsl:template match="define-field">
            <xsl:apply-templates select="formal-name, description"/>
            <xsl:call-template name="give-id"/>
            <string key="type">object</string>
            <xsl:where-populated>
                <map key="properties">
                    <xsl:apply-templates select="." mode="properties"/>
                </map>
            </xsl:where-populated>
            <xsl:call-template name="require-or-allow"/>
            
            <!-- allowed-values only present on fields -->
            <xsl:apply-templates select="constraint/allowed-values"/>
    </xsl:template>
    
    <xsl:template match="define-field[exists(json-value-key/@flag-name)]">
            <xsl:apply-templates select="formal-name, description"/>
            <xsl:call-template name="give-id"/>
            <string key="type">object</string>
            <xsl:where-populated>
                <map key="properties">
                    <xsl:apply-templates select="." mode="properties"/>
                </map>
            </xsl:where-populated>
            <xsl:call-template name="require-or-allow"/>
            
            <!-- calculating required properties to allow for a single property whose
                 key will not be controlled (since it will map to the value-key flag -->
            <xsl:variable name="value-key-name" select="json-value-key/@flag-name"/>
            <xsl:variable name="all-properties" select="flag[not(@ref = $value-key-name)] |
                define-flag[not(@name = $value-key-name)] |
                model/(*|choice)/(field | assembly | define-field | define-assembly)"/>
            <xsl:comment> we require an unspecified property, with any key, to carry the nominal value </xsl:comment>
            <number key="minProperties">
                <xsl:value-of
                    select="count(json-value-key[exists(@flag-name)] | $all-properties[@required = 'yes' or @min-occurs &gt; 0])"
                />
            </number>
            <number key="maxProperties">
                <xsl:value-of
                    select="count($all-properties | self::define-field)"/>
            </number>
            <!-- allowed-values only present on fields -->
            <xsl:apply-templates select="constraint/allowed-values"/>
    </xsl:template>
    
    
    
    <!-- no flags means no properties; but it could be a string or scalar type not an object -->
    <xsl:template match="define-field[empty(flag|define-flag)]">
            <xsl:apply-templates select="formal-name, description"/>
            <xsl:call-template name="give-id"/>
            <xsl:apply-templates select="." mode="object-type"/>
            <xsl:apply-templates select="constraint/allowed-values"/>
    </xsl:template>
    
    <xsl:template match="formal-name" mode="#all">
        <string key="title">
            <xsl:apply-templates/>
        </string>
    </xsl:template>
    
    <xsl:template match="description" mode="#all">
        <string key="description">
            <xsl:value-of select="normalize-space(.)"/>
        </string>
    </xsl:template>
    
    <xsl:template match="remarks | example"/>
    
    <!-- No restriction is introduced when allow others is 'yes' -->
    <xsl:template match="allowed-values[@allow-other='yes']"/>
    
    <xsl:template match="allowed-values">
        <array key="enum">
            <xsl:apply-templates/>
        </array>
    </xsl:template>
    
    <xsl:template match="allowed-values/enum">
        <!-- since the JSON must show enumerated values consistent with the base type notation,
             we determine the nominal type of the node and map it to 'number', 'string' or 'boolean' whichever is best. -->
        <xsl:variable name="type-declaration">
            <xsl:apply-templates select="../parent::constraint/.." mode="object-type"/>
        </xsl:variable>
        <xsl:variable name="nominal-type">
            <xsl:choose>
                <xsl:when test="$type-declaration/*[@key='type']=('integer','number')">number</xsl:when>
                <xsl:when test="$type-declaration/*[@key='type']='boolean'">boolean</xsl:when>
                <xsl:otherwise>string</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <!--<xsl:copy-of select="$type-declaration"/>-->
        <xsl:element namespace="http://www.w3.org/2005/xpath-functions" name="{$nominal-type}">
            <xsl:apply-templates select="@value"/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template name="require-or-allow">
        <xsl:variable name="requirements" as="element()*">
            <!-- A value string is always required except on empty fields -->
            <xsl:variable name="value-property">
                <xsl:apply-templates select="self::define-field" mode="value-key"/>
            </xsl:variable>
            <xsl:for-each select="$value-property[matches(.,'\S')]">
                <string>
                    <xsl:apply-templates/>
                </string>
            </xsl:for-each>
            
            <xsl:variable name="implicit-flags" select="(json-key | json-value-key)/@flag-name"/>
            <xsl:apply-templates mode="property-name"
                select="flag[@required = 'yes'][not(@ref = $implicit-flags)] |
                        define-flag[@required = 'yes'][not(@name = $implicit-flags)] |
                        model/(field|define-field|assembly|define-assembly)[@min-occurs &gt; 0]"/>
        </xsl:variable> 
        <xsl:if test="exists( $requirements )">
            <array key="required">
                <xsl:copy-of select="$requirements"/>
            </array>
        </xsl:if>
        <boolean key="additionalProperties">
            <xsl:choose>
                <xsl:when test="exists(model/(.|choice)/any)">true</xsl:when>
                <xsl:otherwise>false</xsl:otherwise>
            </xsl:choose>
        </boolean>
    </xsl:template>
    
    <!--<xsl:template name="string-or-array-of-strings">
        <array key="oneOf">
            <map>
                <string key="type">string</string>
            </map>
            <map>
                <string key="type">array</string>
                <array key="items">
                    <map>
                        <string key="type">string</string>
                    </map>
                </array>
                <string key="minItems">2</string>
            </map>
        </array>
    </xsl:template>-->
    
    
    <xsl:template match="*" mode="text-property"/>
    
    <xsl:template match="define-field" mode="text-property">
        <string>
          <xsl:apply-templates select="." mode="value-key"/>
        </string>
    </xsl:template>
    
    <xsl:template match="define-field" mode="value-key">
        <xsl:value-of select="$string-value-label"/>
    </xsl:template>
    
    <xsl:template match="define-field[@as-type='markup-line']" mode="value-key">
        <xsl:value-of select="$markdown-value-label"/>
    </xsl:template>
    
    <xsl:template match="define-field[@as-type='markup-multiline']" mode="value-key">
        <xsl:value-of select="$markdown-multiline-label"/>
    </xsl:template>
        
    <xsl:template priority="2" match="define-field[matches(json-value-key,'\S')]" mode="value-key">
        <xsl:value-of select="json-value-key"/>
    </xsl:template>
    
     <!-- No property is declared for a value whose key is assigned by a json-value-key   -->
    <xsl:template priority="3" match="define-field[matches(json-value-key/@flag-name,'\S')]" mode="value-key"/>
        
    <!--<xsl:template priority="3" match="define-field[exists(flag/value-key)]" mode="text-key"/>-->

    <!-- properties of an assembly include its flags and assemblies and fields in its model -->
    <xsl:template match="define-assembly" mode="properties">
        <xsl:apply-templates mode="define" select="flag | define-flag | model"/>
        <!-- to be excluded, flags assigned to be keys -->
        <!--<xsl:variable name="json-key-flag" select="json-key/@flag-name"/>
        <xsl:apply-templates mode="declaration"
            select="flag[not(@ref = $json-key-flag)], define-flag[not(@name = $json-key-flag)], model"/>-->
    </xsl:template>

    <!-- not having a model, the properties of a field are its flags and its value -->
    <xsl:template match="define-field" mode="properties">
        <!--<xsl:variable name="json-key-flag" select="json-key/@flag-name"/>
        <xsl:apply-templates mode="declaration" select="flag[not(@ref = $json-key-flag)], define-flag[not(@name = $json-key-flag)]"/>-->
        <xsl:apply-templates mode="define" select="flag | define-flag"/>
        <xsl:variable name="this-key" as="xs:string?">
            <xsl:apply-templates select="." mode="value-key"/>
        </xsl:variable>
        <xsl:if test="matches($this-key, '\S')">
            <map key="{$this-key}">
                <string key="type">string</string>
            </map>
        </xsl:if>
    </xsl:template>

    <!-- A collapsible field is represented as an object containing
         a string or an array of strings
    turned off for now until we reinstate collapsing into conversion scripts (2020-09-21) -->
    <!--<xsl:template match="define-field[@collapsible='yes']" mode="properties">
        <!-\-<xsl:variable name="json-key-flag" select="json-key/@flag-name"/>
        <xsl:apply-templates mode="declaration" select="flag[not(@ref = $json-key-flag)], define-flag[not(@name = $json-key-flag)]"/>-\->
        <xsl:apply-templates mode="define" select="flag | define-flag"/>
        <xsl:variable name="this-key" as="xs:string?">
            <xsl:apply-templates select="." mode="value-key"/>
        </xsl:variable>
        <xsl:if test="matches($this-key, '\S')">
            <map key="{$this-key}">
                <array key="anyOf">
                    <map><string key="type">string</string></map>
                    <map>
                        <string key="type">array</string>
                        <map key="items">
                            <string key="type">string</string>
                        </map>
                        <number key="minItems">1</number><!-\- See Issue #536 -\->
                    </map>
                </array>
            </map>
        </xsl:if>
    </xsl:template>-->
    
    <!--<xsl:template priority="2" mode="property-name" match="assembly">
        <xsl:apply-templates mode="#current" select="key('assembly-definition-by-name',@_key-ref)"/>
    </xsl:template>
    
    <xsl:template priority="2" mode="property-name" match="field">
        <xsl:apply-templates mode="#current" select="key('field-definition-by-name',@_key-ref)"/>
    </xsl:template>
    
    <xsl:template priority="2" mode="property-name" match="flag">
        <xsl:apply-templates mode="#current" select="key('flag-definition-by-name',@_key-ref)"/>
    </xsl:template>-->
    
    <xsl:template priority="2" mode="property-name" match="define-field | define-assembly | define-flag | assembly | field | flag" expand-text="true">
        <string>{ @_in-json-name }</string>
    </xsl:template>
    
    <!-- Handled by template 'require-or-allow' -->
    <xsl:template match="any" mode="property-name"/>
    
    <xsl:template match="model | choice" priority="2" mode="property-name">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    
    <!--A flag declared as a key or value key gets no declaration since it
    will not show up in the JSON as a separate property -->
    
    <xsl:template mode="define" priority="5" match="define-flag[@name=../(json-value-key|json-key)/@flag-name] |
        flag[@ref=../(json-value-key|json-key)/@flag-name]"/>
    
    
    <xsl:template mode="define" match="flag">
        <xsl:variable name="decl" select="key('flag-definition-by-name', @_key-ref)"/>
        <map key="{ (use-name,$decl/use-name,$decl/@name)[1] }">
            <xsl:apply-templates select="$decl/(formal-name | description)"/>
            <xsl:apply-templates select="." mode="object-type"/>
            <xsl:apply-templates select="$decl/constraint/allowed-values"/>
        </map>
    </xsl:template>
    
    <!--<xsl:template mode="declaration" match="model//define-field">
        <map key="{ (group-as/@name,use-name,@name)[1] }">
            <xsl:apply-templates select="formal-name | description"/>
            <xsl:apply-templates select="." mode="object-type"/>
            <xsl:apply-templates select="constraint/allowed-values"/>    
        </map>
    </xsl:template>-->
    
    <xsl:template mode="define" match="define-assembly/define-flag | define-field/define-flag">
        <map key="{ (use-name,@name)[1] }">
            <xsl:apply-templates select="formal-name | description"/>
            <xsl:apply-templates select="." mode="object-type"/>
            <xsl:apply-templates select="constraint/allowed-values"/>    
        </map>
    </xsl:template>
    
    <!-- irrespective of min-occurs and max-occurs, assemblies and fields designated
         with key flags are represented as objects, never arrays, as the key
         flag serves as a label -->
    <xsl:template mode="define" priority="5"
        match="define-assembly[group-as/@in-json='BY_KEY'][exists(json-key)] |
        define-field[group-as/@in-json='BY_KEY'][exists(json-key)] |
        assembly[group-as/@in-json='BY_KEY'][exists(key('assembly-definition-by-name',@_key-ref)/json-key)] |
        field[group-as/@in-json='BY_KEY'][exists(key('field-definition-by-name',@_key-ref)/json-key)]">
        <xsl:variable name="group-name" select="group-as/@name"/>
        <map key="{ $group-name }">
            <string key="type">object</string>
            <number key="minProperties">1</number>
            <map key="additionalProperties">
                <array key="allOf">
                    <map>
                        <xsl:apply-templates select="." mode="definition-or-reference"/>
                    </map>
                    <map>
                        <map key="not">
                            <string key="type">string</string>
                        </map>
                    </map>
                </array>
            </map>
        </map>
    </xsl:template>
    
    <!-- Always a map when max-occurs is 1 or implicit -->
    <xsl:template mode="define" priority="4"
        match="assembly[empty(@max-occurs) or number(@max-occurs) = 1] | define-assembly[empty(@max-occurs) or number(@max-occurs) = 1]">
        <xsl:variable name="decl" select="key('assembly-definition-by-name', @_key-ref) | self::define-assembly"/>
        <map key="{ (use-name,$decl/use-name,$decl/@name)[1] }">
            <xsl:apply-templates select="." mode="definition-or-reference"/>
        </map>
    </xsl:template>
    
    <!-- Always a map when max-occurs is 1 or implicit -->
    <xsl:template mode="define" priority="4"
        match="field[empty(@max-occurs) or number(@max-occurs) = 1] | define-field[empty(@max-occurs) or number(@max-occurs) = 1]">
        <xsl:variable name="decl" select="key('field-definition-by-name', @_key-ref) | self::define-field"/>
        <map key="{ (use-name,$decl/use-name,$decl/@name)[1] }">
            <xsl:apply-templates select="." mode="definition-or-reference"/>
        </map>
    </xsl:template>
    
    <!-- Otherwise, always an array when min-occurs is greater than 1 or whenever so designated -->
    <xsl:template mode="define" priority="3" expand-text="yes"
        match="*[number(@min-occurs) &gt; 1 ] | *[child::group-as/@in-json='ARRAY']">
        <map key="{ group-as/@name }">
            <string key="type">array</string>
            <!-- despite @min-occurs = 0, we have a minimum of 1 since the array itself is optional -->
            <number key="minItems">{ max((@min-occurs/number(),1)) }</number>
            <!-- case for @max-occurs missing or 1 has matched the template above -->
            <xsl:for-each select="@max-occurs[not(. = 'unbounded')]">
                <number key="maxItems">{ . }</number>
            </xsl:for-each>
            <map key="items">
                <xsl:apply-templates select="." mode="definition-or-reference"/>
            </map>
        </map>
    </xsl:template>
    
    <!-- Now matching when min-occurs is 1 or less, max-occurs is more than 1,
         and group-as/@in-json is not 'BY-KEY' or 'ARRAY' ... -->
    <xsl:template mode="define" match="assembly | field | define-assembly | define-field">
        <map key="{ group-as/@name }">
            <array key="anyOf">
                <map>
                    <xsl:apply-templates select="." mode="definition-or-reference"/>
                </map>
                <map>
                    <string key="type">array</string>
                    <xsl:if test="@max-occurs != 'unbounded'">
                        <number key="maxItems">{ @max-occurs }</number>
                    </xsl:if>
                    <number key="minItems">1</number><!-- See Issue #536 -->
                    <map key="items">
                        <xsl:apply-templates select="." mode="definition-or-reference"/>
                    </map>
                </map>
            </array>
        </map>
    </xsl:template>
    
    
    <xsl:template match="define-assembly | define-field | define-flag" mode="definition-or-reference">
        <xsl:apply-templates select="."/>
    </xsl:template>
    
    
    <xsl:template match="model/define-assembly | model/define-field | model/define-flag" mode="definition-or-reference">
        <xsl:apply-templates select="."/>
    </xsl:template>
    
    <xsl:template match="flag" mode="definition-or-reference">
        <xsl:variable name="definition" select="key('flag-definition-by-name',@_key-ref)"/>
        <xsl:apply-templates select="$definition" mode="make-ref"/>
    </xsl:template>
    
    <xsl:template match="field" mode="definition-or-reference">
        <xsl:variable name="definition" select="key('field-definition-by-name',@_key-ref)"/>
        <xsl:apply-templates select="$definition" mode="make-ref"/>
    </xsl:template>
    
    <xsl:template match="assembly" mode="definition-or-reference">
        <xsl:variable name="definition" select="key('assembly-definition-by-name',@_key-ref)"/>
        <xsl:apply-templates select="$definition" mode="make-ref"/>
    </xsl:template>
    
    <!--  elements that fall through are made objects in case they have properties  -->
    <xsl:template match="*" mode="object-type">
        <string key="type">object</string>
    </xsl:template>

    <xsl:template match="define-flag | flag" mode="object-type">
        <string key="type">string</string>
    </xsl:template>
    
    <xsl:template match="define-field" mode="object-type">
        <xsl:variable name="implicit-flags" select="(json-key | json-value-key)/@flag-name"/>
        <xsl:choose>
            <xsl:when test="empty(flag[not(@ref=$implicit-flags)] | define-flag[not(@name=$implicit-flags)])">
                <string key="type">string</string>        
            </xsl:when>
            <xsl:otherwise>
                <xsl:next-match/>
            </xsl:otherwise>
        </xsl:choose>
        
    </xsl:template>
    
    <xsl:template match="field" priority="3" mode="object-type">
        <xsl:choose>
            <xsl:when test="exists(@as-type)">
                <xsl:next-match/>
            </xsl:when>
            <xsl:when test="exists(key('field-definition-by-name',@_key-ref)/@as-type)">
                <xsl:apply-templates mode="#current" select="key('field-definition-by-name',@_key-ref)"/>
            </xsl:when>
            <xsl:otherwise>
                <string key="type">string</string> 
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="model//define-field" priority="3" mode="object-type">
        <xsl:choose>
            <xsl:when test="exists(@as-type)">
                <xsl:next-match/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:next-match/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="flag | define-assembly/define-flag | define-field/define-flag" priority="3" mode="object-type">
        <xsl:choose>
            <xsl:when test="exists(@as-type)">
                <xsl:next-match/>
            </xsl:when>
            <xsl:when test="exists(key('flag-definition-by-name',@_key-ref)/@as-type)">
                <xsl:apply-templates mode="#current" select="key('flag-definition-by-name',@_key-ref)"/>
            </xsl:when>
            <xsl:otherwise>
                <string key="type">string</string> 
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!-- currently working on flags but not on fields with flags? -->
    <xsl:template priority="2" match="*[@as-type='boolean']" mode="object-type">
        <string key="type">boolean</string>
    </xsl:template>
    
    <xsl:template priority="2" match="*[@as-type='integer']" mode="object-type">
        <string key="type">integer</string>
        <!--<number key="multipleOf">1.0</number>-->
    </xsl:template>

    <xsl:template priority="2" match="*[@as-type='positiveInteger']" mode="object-type">
        <string key="type">integer</string>
        <number key="multipleOf">1.0</number>
        <number key="minimum">1</number>
    </xsl:template>    
    
    <xsl:template priority="2" match="*[@as-type='nonNegativeInteger']" mode="object-type">
        <string key="type">integer</string>
        <number key="multipleOf">1.0</number>
        <number key="minimum">0</number>
    </xsl:template>
    
    <!--Not supporting float or double--> 

    <xsl:template priority="2.1" match="*[@as-type = $datatypes/*/@key]" mode="object-type">
        <xsl:apply-templates mode="acquire-types" select="key('datatypes-by-name',@as-type,$datatypes)/*"/>
    </xsl:template>
    
    <xsl:mode name="acquire-types" on-no-match="shallow-copy"/>
    
    <xsl:template mode="acquire-types" xpath-default-namespace="http://www.w3.org/2005/xpath-functions" match="string[@key='description']">
      <!--<string key="datatype-description">
          <xsl:apply-templates/>
      </string>  -->  
    </xsl:template>
    
    <xsl:key name="datatypes-by-name" xpath-default-namespace="http://www.w3.org/2005/xpath-functions"
        match="map" use="@key"/>
    
    <!--<xsl:variable name="datatypes" expand-text="false">
        <dummy/>
    </xsl:variable>-->
        
    <xsl:variable name="datatypes" expand-text="false">
        <!-- First, grabbing raw JSON out of line definitions copied from -->
        <!-- https://raw.githubusercontent.com/usnistgov/metaschema/feature-metaschema-relocation-plus-enhancements
            /schema/json/metaschema-datatypes.json       -->
        
        <xsl:copy-of xpath-default-namespace="http://www.w3.org/2005/xpath-functions" select="( unparsed-text('metaschema-v090-datatypes.json') => json-to-xml() )/map/map[@key='definitions']/map"/>
        
        <!-- Now the old names, for backward compatibility, amended with new definitions. -->
        <map key="decimal"><!-- DecimalDatatype -->
            <string key="type">number</string>
            <!--<string key="pattern">^(\+|-)?([0-9]+(\.[0-9]*)?|\.[0-9]+)$</string>-->
        </map>
        <map key="date"><!-- DateDatatype -->
            <string key="type">string</string>
            <string key="pattern">^((2000|2400|2800|(19|2[0-9](0[48]|[2468][048]|[13579][26])))-02-29)|(((19|2[0-9])[0-9]{2})-02-(0[1-9]|1[0-9]|2[0-8]))|(((19|2[0-9])[0-9]{2})-(0[13578]|10|12)-(0[1-9]|[12][0-9]|3[01]))|(((19|2[0-9])[0-9]{2})-(0[469]|11)-(0[1-9]|[12][0-9]|30))(Z|[+-][0-9]{2}:[0-9]{2})?$</string>
        </map>
        <map key="dateTime"><!-- DateTimeDatatype -->
            <string key="type">string</string>
            <string key="pattern">^((2000|2400|2800|(19|2[0-9](0[48]|[2468][048]|[13579][26])))-02-29)|(((19|2[0-9])[0-9]{2})-02-(0[1-9]|1[0-9]|2[0-8]))|(((19|2[0-9])[0-9]{2})-(0[13578]|10|12)-(0[1-9]|[12][0-9]|3[01]))|(((19|2[0-9])[0-9]{2})-(0[469]|11)-(0[1-9]|[12][0-9]|30))T(2[0-3]|[01][0-9]):([0-5][0-9]):([0-5][0-9])(\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})?$</string>
        </map>
        <map key="date-with-timezone"><!-- DateWithTimezoneDatatype -->
            <string key="type">string</string>
            <string key="pattern">^((2000|2400|2800|(19|2[0-9](0[48]|[2468][048]|[13579][26])))-02-29)|(((19|2[0-9])[0-9]{2})-02-(0[1-9]|1[0-9]|2[0-8]))|(((19|2[0-9])[0-9]{2})-(0[13578]|10|12)-(0[1-9]|[12][0-9]|3[01]))|(((19|2[0-9])[0-9]{2})-(0[469]|11)-(0[1-9]|[12][0-9]|30))(Z|[+-][0-9]{2}:[0-9]{2})$</string>
        </map>
        <map key="dateTime-with-timezone"><!-- DateTimeWithTimezoneDatatype -->
            <string key="type">string</string>
            <string key="format">date-time</string>
            <string key="pattern">^((2000|2400|2800|(19|2[0-9](0[48]|[2468][048]|[13579][26])))-02-29)|(((19|2[0-9])[0-9]{2})-02-(0[1-9]|1[0-9]|2[0-8]))|(((19|2[0-9])[0-9]{2})-(0[13578]|10|12)-(0[1-9]|[12][0-9]|3[01]))|(((19|2[0-9])[0-9]{2})-(0[469]|11)-(0[1-9]|[12][0-9]|30))T(2[0-3]|[01][0-9]):([0-5][0-9]):([0-5][0-9])(\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$</string>
        </map>
        <map key="email"><!-- EmailAddressDatatype -->
            <string key="type">string</string>
            <string key="format">email</string>
            <string key="pattern">^.+@.+$</string>
        </map>
        <map key="ip-v4-address"><!-- IPV4AddressDatatype -->
            <string key="type">string</string>
            <string key="format">ipv4</string>
            <string key="pattern">^((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9]).){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])$</string>
        </map>
        <map key="ip-v6-address"><!-- IPV6AddressDatatype -->
            <string key="type">string</string>
            <string key="format">ipv6</string>
            <string key="pattern">^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|[fF][eE]80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::([fF]{4}(:0{1,4}){0,1}:){0,1}((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9]).){3,3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9]).){3,3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9]))$</string>
        </map>
        <map key="hostname"><!-- HostnameDatatype -->
            <string key="$ref">#/definitions/StringDatatype</string>
            <string key="format">idn-hostname</string>
        </map>
        <map key="uri"><!-- URIDatatype -->
            <string key="type">string</string>
            <string key="format">uri</string>
            <string key="pattern">^[a-zA-Z][a-zA-Z0-9+\-.]+:.+$</string>
        </map>
        <map key="uri-reference"><!-- URIReferenceDatatype -->
            <string key="type">string</string>
            <string key="format">uri-reference</string>
        </map>
        <map key="uuid"><!-- UUIDDatatype -->
            <string key="type">string</string>
            <string key="description">A type 4 ('random' or 'pseudorandom') or type 5 UUID per RFC 4122.</string>
            <string key="pattern">^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[45][0-9A-Fa-f]{3}-[89ABab][0-9A-Fa-f]{3}-[0-9A-Fa-f]{12}$</string>
        </map>
        <map xmlns="http://www.w3.org/2005/xpath-functions" key="token"><!-- TokenDatatype -->
            <string key="type">string</string>
            <string key="pattern">^(\p{L}|_)(\p{L}|\p{N}|[.\-_])*$</string>
        </map>
        
        <map key="string">
            <string key="type">string</string>
            <string key="pattern">^\S(.*\S)?$</string>
            <!---->
        </map>
    </xsl:variable>

</xsl:stylesheet>
