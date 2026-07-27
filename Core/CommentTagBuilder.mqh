//+------------------------------------------------------------------+
//|                                         CommentTagBuilder.mqh    |
//|                                  Copyright 2026, CORTEX_MK6 CORE |
//|                                                                  |
//| DESCRIPCIÓN:                                                      |
//| Generador de Comentarios de Orden Estandarizados (Prefijo CTX_)   |
//| para Rastreabilidad Institucional de CORTEX_MK6 v2.2.0.          |
//+------------------------------------------------------------------+
#ifndef COMMENT_TAG_BUILDER_MQH
#define COMMENT_TAG_BUILDER_MQH

#property copyright "Copyright 2026, CORTEX_MK6 CORE"
#property strict

class CCommentTagBuilder
{
public:
    // Construye la etiqueta de comentario con el formato "CTX_M<Engine>_T<Tier>_L<Level>"
    static string BuildTag(int engineId, int tier, int gridLevel = 0)
    {
        return StringFormat("CTX_M%d_T%d_L%d", engineId, tier, gridLevel);
    }
};

#endif
